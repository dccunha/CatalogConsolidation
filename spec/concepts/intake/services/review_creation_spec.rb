require "rails_helper"

RSpec.describe Intake::Services::ReviewActions, type: :model do
  let(:source) do
    { "Id" => "new-007", "SellerName" => "Review Seller", "Name" => "Canon Camera",
      "Brand" => "Canon", "Category" => "Photo" }
  end
  let!(:candidate_product) do
    FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon", category: "Photography")
  end

  def import(row = source)
    Intake::Services::ImportProcessor.call(json: [ row ].to_json, source_name: "creation.json")
  end

  def review_case
    @review_case ||= Intake::Models::ReviewCase.order(:id).last
  end

  def reject(candidate, revision: review_case.evidence_revision)
    described_class.reject(review_case_id: review_case.id, candidate_id: candidate.id,
      evidence_revision: revision, reason: "Wrong sellable variant")
  end

  def create(revision: review_case.evidence_revision)
    described_class.create(review_case_id: review_case.id, evidence_revision: revision)
  end

  describe ".create" do
    it "waits for a separate creation decision after the last rejection and replays it on rerun" do
      import
      first = review_case.review_candidates.sole

      expect(reject(first).status).to eq(:rejected)
      expect(described_class.creation_state(review_case: review_case)).to eq(:ready)
      expect(review_case.reload.status).to eq("pending")
      expect(Catalog::Models::Product.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(Intake::Models::ReviewDecision.count).to eq(0)

      result = create

      expect(result.status).to eq(:created)
      expect(review_case.reload.status).to eq("resolved")
      decision = review_case.review_decision
      association = Catalog::Models::SellerProduct.find_by!(seller_name: source.fetch("SellerName"),
        seller_product_id: source.fetch("Id"))
      expect(Catalog::Models::Product.count).to eq(2)
      expect(association.product_id).to eq(decision.product_id)
      expect(association.product).to have_attributes(name: "Canon Camera", brand: "Canon", category: "Photo")
      expect(decision).to have_attributes(result: "created", reviewer: Intake::Reviewer.name)
      expect(decision.decided_at).to be_present
      expect(review_case.review_candidates.joins(:review_rejection).sole.product_id).to eq(candidate_product.id)
      expect(review_case.source_input).to eq(source)
      expect(create.status).to eq(:not_actionable)

      rerun = import
      expect(rerun.rows.sole).to have_attributes(outcome: "already_imported", product_id: decision.product_id)
      expect(rerun.rows.sole.reason).to include("retained created decision")
      expect(Catalog::Models::Product.count).to eq(2)
      expect(Catalog::Models::SellerProduct.count).to eq(1)
      expect(Intake::Models::ReviewDecision.count).to eq(1)
    end

    it "requires complete metadata, then a separate creation after correction" do
      incomplete = source.merge("Name" => "Unlisted accessory", "Brand" => nil)
      import(incomplete)

      expect(described_class.creation_state(review_case: review_case)).to eq(:incomplete)
      expect(create.status).to eq(:invalid)
      expect(Catalog::Models::Product.count).to eq(1)

      correction = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Unlisted accessory", brand: "Acme", category: "Photo")
      expect(correction.status).to eq(:corrected)
      expect(review_case.reload.status).to eq("pending")
      expect(described_class.creation_state(review_case: review_case)).to eq(:ready)
      expect(Catalog::Models::Product.count).to eq(1)

      expect(create(revision: 1).status).to eq(:stale)
      expect(create(revision: 2).status).to eq(:created)
      expect(review_case.reload.review_decision.product_id).to eq(review_case.seller_item.product_id)
      expect(Catalog::Models::Product.order(:id).last).to have_attributes(name: "Unlisted accessory",
        brand: "Acme", category: "Photo")
      expect(review_case.source_input).to eq(incomplete)
      expect(review_case.review_corrections.sole.corrected_input).to include("Brand" => "Acme",
        "Id" => incomplete.fetch("Id"), "SellerName" => incomplete.fetch("SellerName"))
      expect(import(incomplete).rows.sole.reason).to include("retained created decision")
    end

    it "shows new credible candidates before creation and keeps earlier rejections" do
      import
      reject(review_case.review_candidates.sole)
      new_product = FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon",
        category: "Electronics")

      result = create(revision: 1)

      expect(result.status).to eq(:stale)
      expect(review_case.reload).to have_attributes(status: "pending", evidence_revision: 2)
      expect(review_case.review_candidates.where(evidence_revision: 2).order(:rank).pluck(:product_id)).to contain_exactly(
        candidate_product.id, new_product.id)
      expect(described_class.creation_state(review_case: review_case)).to eq(:candidates)
      expect(create(revision: 1).status).to eq(:stale)
      expect(create(revision: 2).status).to eq(:invalid)
      expect(review_case.review_candidates.joins(:review_rejection).pluck(:product_id)).to eq([ candidate_product.id ])
      expect(Catalog::Models::Product.count).to eq(2)
      expect(Catalog::Models::SellerProduct.count).to eq(0)

      next_candidate = review_case.review_candidates.where(evidence_revision: 2, product_id: new_product.id).sole
      expect(reject(next_candidate, revision: 2).status).to eq(:rejected)
      expect(described_class.creation_state(review_case: review_case)).to eq(:ready)
      expect(create(revision: 2).status).to eq(:created)
      expect(Catalog::Models::Product.count).to eq(3)
      expect(Intake::Models::ReviewRejection.count).to eq(2)
    end

    it "does not let another seller ID's rejected candidate conflict block creation" do
      Catalog::Models::SellerProduct.create!(seller_name: source.fetch("SellerName"),
        seller_product_id: "other-id", product_id: candidate_product.id)
      import

      expect(reject(review_case.review_candidates.sole).status).to eq(:rejected)
      expect(described_class.creation_state(review_case: review_case)).to eq(:ready)
      expect(create.status).to eq(:created)
      expect(Catalog::Models::SellerProduct.count).to eq(2)
    end

    it "refreshes a new association for the same seller key and leaves reassignment pending" do
      import
      reject(review_case.review_candidates.sole)
      Catalog::Models::SellerProduct.create!(seller_name: source.fetch("SellerName"),
        seller_product_id: source.fetch("Id"), product_id: candidate_product.id)

      expect(create.status).to eq(:stale)
      expect(review_case.reload).to have_attributes(status: "pending", evidence_revision: 2)
      expect(review_case.conflicting_association).to include("seller_product_id" => source.fetch("Id"))
      expect(described_class.creation_state(review_case: review_case)).to eq(:association_conflict)
      expect(create(revision: 2).status).to eq(:conflict)
      expect(Catalog::Models::Product.count).to eq(1)
      expect(Intake::Models::ReviewDecision.count).to eq(0)
    end

    it "keeps an existing seller item association for T13 reassignment" do
      Catalog::Models::SellerProduct.create!(seller_name: source.fetch("SellerName"),
        seller_product_id: source.fetch("Id"), product_id: candidate_product.id)
      import(source.merge("Name" => "Different item", "Brand" => "Other", "Category" => "Other"))

      expect(described_class.creation_state(review_case: review_case)).to eq(:association_conflict)
      expect(create.status).to eq(:conflict)
      expect(review_case.reload.status).to eq("pending")
      expect(Catalog::Models::Product.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(1)
    end

    it "rolls back the product and association when final decision persistence fails" do
      import
      reject(review_case.review_candidates.sole)
      allow(Intake::Models::ReviewDecision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { create }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Catalog::Models::Product.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(Intake::Models::ReviewDecision.count).to eq(0)
      expect(review_case.reload.status).to eq("pending")
      expect(review_case.seller_item.reload).to have_attributes(resolution: "pending", product_id: nil)
      expect(Intake::Models::ReviewRejection.count).to eq(1)
    end
  end
end
