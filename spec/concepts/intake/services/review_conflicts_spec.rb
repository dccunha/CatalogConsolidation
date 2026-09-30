require "rails_helper"

RSpec.describe Intake::Services::ReviewActions, type: :model do
  let(:seller) { "Conflict Seller" }
  let(:old_row) do
    { "SellerName" => seller, "Id" => "old-id", "Name" => "Camera One",
      "Brand" => "Canon", "Category" => "Photo" }
  end
  let(:incoming_row) { old_row.merge("Id" => "new-id") }

  def import(row)
    Intake::Services::ImportProcessor.call(json: [ row ].to_json, source_name: "conflict.json").rows.sole
  end

  def pending_case(row)
    Intake::Models::ReviewCase.find(import(row).review_case_id)
  end

  def selected_candidate(review_case, product)
    review_case.review_candidates.where(evidence_revision: review_case.evidence_revision, product_id: product.id).sole
  end

  def association(id)
    Catalog::Models::SellerProduct.find_by(seller_name: seller, seller_product_id: id)
  end

  describe ".reassign_candidate" do
    it "preserves the old association until approval, then keeps a returning old identity pending" do
      old = import(old_row)
      target = FactoryBot.create(:catalog_product, name: "Camera Two", brand: "Canon", category: "Photo")
      changed = old_row.merge("Name" => "Camera Two")
      review_case = pending_case(changed)
      candidate = selected_candidate(review_case, target)

      expect(association("old-id").product_id).to eq(old.product_id)
      expect(review_case.seller_item.product_id).to eq(old.product_id)

      result = described_class.reassign_candidate(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:approved)
      expect(association("old-id").product_id).to eq(target.id)
      expect(review_case.reload.review_decision).to have_attributes(result: "linked", product_id: target.id)
      expect(import(changed)).to have_attributes(outcome: "already_imported", product_id: target.id)
      returning = import(old_row)
      expect(returning).to have_attributes(outcome: "pending_review", product_id: nil)
      expect(association("old-id").product_id).to eq(target.id)
      expect(described_class.reassign_candidate(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1).status).to eq(:not_actionable)
    end

    it "refreshes a changed association and refuses stale or superseded submissions" do
      import(old_row)
      target = FactoryBot.create(:catalog_product, name: "Camera Two", brand: "Canon", category: "Photo")
      review_case = pending_case(old_row.merge("Name" => "Camera Two"))
      candidate = selected_candidate(review_case, target)
      alternate = FactoryBot.create(:catalog_product, name: "Camera Three", brand: "Canon", category: "Photo")
      current = association("old-id")
      Catalog::Public::Writes.reassign(association_id: current.id, product_id: alternate.id,
        seller_product_id: "old-id")

      result = described_class.reassign_candidate(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:stale)
      expect(review_case.reload).to have_attributes(status: "pending", evidence_revision: 2)
      expect(review_case.review_decision).to be_nil
      expect(association("old-id").product_id).to eq(alternate.id)
      expect(described_class.reassign_candidate(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1).status).to eq(:stale)
      import(old_row.merge("Name" => "Camera Four"))
      expect(described_class.reassign_candidate(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 2).status).to eq(:not_actionable)
    end
  end

  describe ".create_for_reassignment" do
    it "requires rejection and atomically moves an existing association to a new product" do
      old = import(old_row)
      similar = FactoryBot.create(:catalog_product, name: "Camera One Mark II", brand: "Canon", category: "Photo")
      changed = old_row.merge("Name" => "Camera One Mark II", "Category" => "Electronics")
      review_case = pending_case(changed)
      candidate = selected_candidate(review_case, similar)

      expect(described_class.reassignment_creation_state(review_case: review_case)).to eq(:candidates)
      expect(described_class.create_for_reassignment(review_case_id: review_case.id,
        evidence_revision: 1).status).to eq(:invalid)
      expect(association("old-id").product_id).to eq(old.product_id)
      expect(described_class.reject(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1, reason: "Different model").status).to eq(:rejected)
      expect(described_class.reassignment_creation_state(review_case: review_case)).to eq(:ready)

      result = described_class.create_for_reassignment(review_case_id: review_case.id, evidence_revision: 1)

      expect(result.status).to eq(:created)
      expect(association("old-id").product).to have_attributes(name: changed.fetch("Name"),
        brand: "Canon", category: "Electronics")
      expect(review_case.reload.review_decision).to have_attributes(result: "created",
        product_id: association("old-id").product_id)
      expect(import(changed)).to have_attributes(outcome: "already_imported",
        product_id: association("old-id").product_id)
      expect(Catalog::Models::SellerProduct.where(seller_name: seller).count).to eq(1)
    end

    it "rolls back product creation and association movement if Intake decision fails" do
      import(old_row)
      review_case = pending_case(old_row.merge("Name" => "Unlisted replacement"))
      original = association("old-id").product_id
      count = Catalog::Models::Product.count
      allow(Intake::Models::ReviewDecision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect do
        described_class.create_for_reassignment(review_case_id: review_case.id, evidence_revision: 1)
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(Catalog::Models::Product.count).to eq(count)
      expect(association("old-id").product_id).to eq(original)
      expect(review_case.reload.status).to eq("pending")
    end
  end

  describe "same-seller conflict decisions" do
    it "keeps the old ID, declines the incoming ID, and does not relink an unchanged rerun" do
      old = import(old_row)
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))

      result = described_class.keep_existing(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:kept_existing)
      expect(association("old-id").product_id).to eq(old.product_id)
      expect(association("new-id")).to be_nil
      expect(review_case.reload.review_decision).to have_attributes(result: "kept_existing",
        declined_seller_item_id: review_case.seller_item_id, product_id: old.product_id)
      expect(review_case.seller_item.reload).to have_attributes(resolution: "declined", product_id: nil)
      expect(import(incoming_row)).to have_attributes(outcome: "already_imported", product_id: nil)
      expect(import(incoming_row.merge("Name" => "Another camera")).outcome).to eq("pending_review")
      expect(association("new-id")).to be_nil
    end

    it "replaces the old ID, retains its displaced outcome, and leaves its changed rerun in review" do
      old = import(old_row)
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))
      old_item = Intake::Models::SellerItem.find_exact(seller_name: seller, seller_product_id: "old-id")

      result = described_class.replace_existing(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:replaced)
      expect(association("old-id")).to be_nil
      expect(association("new-id").product_id).to eq(old.product_id)
      expect(old_item.reload).to have_attributes(resolution: "displaced", product_id: nil)
      expect(review_case.reload.review_decision).to have_attributes(result: "linked",
        displaced_seller_item_id: old_item.id, product_id: old.product_id)
      expect(import(old_row)).to have_attributes(outcome: "already_imported", product_id: nil)
      expect(import(old_row.merge("Name" => "Camera Four")).outcome).to eq("pending_review")
      expect(association("old-id")).to be_nil
      expect(described_class.replace_existing(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1).status).to eq(:not_actionable)
    end

    it "retires the incoming association when both IDs are linked and the reviewer keeps the old ID" do
      old = import(old_row)
      second = import(incoming_row.merge("Name" => "Another item"))
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))
      expect(association("new-id").product_id).to eq(second.product_id)

      result = described_class.keep_existing(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:kept_existing)
      expect(association("old-id").product_id).to eq(old.product_id)
      expect(association("new-id")).to be_nil
      expect(review_case.seller_item.reload).to have_attributes(resolution: "declined", product_id: nil)
      expect(import(incoming_row)).to have_attributes(outcome: "already_imported", product_id: nil)
    end

    it "replaces the old association when both IDs were linked to different products" do
      old = import(old_row)
      second = import(incoming_row.merge("Name" => "Another item"))
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))

      result = described_class.replace_existing(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:replaced)
      expect(association("old-id")).to be_nil
      expect(association("new-id").product_id).to eq(old.product_id)
      expect(Catalog::Models::Product.exists?(second.product_id)).to be(true)
      expect(import(old_row)).to have_attributes(outcome: "already_imported", product_id: nil)
      expect(import(incoming_row)).to have_attributes(outcome: "already_imported", product_id: old.product_id)
    end

    it "refreshes changed conflict evidence without writing a decision" do
      old = import(old_row)
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))
      association_record = association("old-id")
      replacement = FactoryBot.create(:catalog_product, name: "Different camera", brand: "Canon",
        category: "Photo")
      Catalog::Public::Writes.reassign(association_id: association_record.id, product_id: replacement.id,
        seller_product_id: "old-id")

      result = described_class.replace_existing(review_case_id: review_case.id, candidate_id: candidate.id,
        evidence_revision: 1)

      expect(result.status).to eq(:stale)
      expect(review_case.reload).to have_attributes(status: "pending", evidence_revision: 2)
      expect(association("old-id").product_id).to eq(replacement.id)
      expect(association("new-id")).to be_nil
      expect(review_case.review_decision).to be_nil
    end

    it "rolls back both associations and both seller items after a failed replacement decision" do
      old = import(old_row)
      second = import(incoming_row.merge("Name" => "Another item"))
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))
      allow(Intake::Models::ReviewDecision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect do
        described_class.replace_existing(review_case_id: review_case.id, candidate_id: candidate.id,
          evidence_revision: 1)
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(association("old-id").product_id).to eq(old.product_id)
      expect(association("new-id").product_id).to eq(second.product_id)
      expect(review_case.seller_item.reload).to have_attributes(resolution: "pending", product_id: second.product_id)
      expect(Intake::Models::SellerItem.find_exact(seller_name: seller,
        seller_product_id: "old-id").reload.product_id).to eq(old.product_id)
      expect(review_case.reload.status).to eq("pending")
    end

    it "rolls back a retired incoming association when the keep decision fails" do
      old = import(old_row)
      second = import(incoming_row.merge("Name" => "Another item"))
      review_case = pending_case(incoming_row)
      candidate = selected_candidate(review_case, Catalog::Models::Product.find(old.product_id))
      allow(Intake::Models::ReviewDecision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect do
        described_class.keep_existing(review_case_id: review_case.id, candidate_id: candidate.id,
          evidence_revision: 1)
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(association("old-id").product_id).to eq(old.product_id)
      expect(association("new-id").product_id).to eq(second.product_id)
      expect(review_case.seller_item.reload).to have_attributes(resolution: "pending", product_id: second.product_id)
      expect(review_case.reload.status).to eq("pending")
    end
  end
end
