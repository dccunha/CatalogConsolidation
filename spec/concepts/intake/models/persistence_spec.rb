require "rails_helper"

RSpec.describe "Intake persistence", type: :model do
  let(:batch) { Intake::Models::Batch.create!(source_name: "file.json", input_count: 3, created_at: Time.current) }
  let(:source_input) do
    { "Id" => "001", "SellerName" => "MegaStore", "Name" => "Câmera", "Brand" => "Acme", "Category" => "Photo" }
  end
  let(:comparison) { { "name" => "camera", "brand" => "acme", "category" => "photo" } }
  let(:seller_item) do
    Intake::Models::SellerItem.create!(seller_name: "MegaStore", seller_product_id: "001",
      active_source_input: source_input, active_source_comparison: comparison, resolution: "pending")
  end
  let(:review_case) do
    Intake::Models::ReviewCase.create!(seller_item: seller_item, batch: batch, source_position: 1,
      status: "pending", reason: "candidate_review", source_input: source_input,
      source_comparison: comparison)
  end

  describe "row-result audit" do
    it "addresses invalid elements by position without inventing a seller key" do
      first = Intake::Models::RowResult.create!(batch: batch, source_position: 1, input_json: "null",
        outcome: "failed", reason: "not_an_object", validation_errors: [ { field: nil, code: "not_an_object" } ])
      second = Intake::Models::RowResult.create!(batch: batch, source_position: 2,
        input_json: '{"Id":null}', outcome: "failed", reason: "invalid_id")

      expect(batch.row_results.order(:source_position).pluck(:id)).to eq([ first.id, second.id ])
      expect(first.reload.attributes.slice("seller_name", "seller_product_id", "input_json")).to eq(
        "seller_name" => nil, "seller_product_id" => nil, "input_json" => "null"
      )
      expect(second.reload.input_json).to eq('{"Id":null}')
    end

    it "preserves import-time pending outcomes after a case resolves" do
      row = Intake::Models::RowResult.create!(batch: batch, source_position: 1,
        input_json: source_input.to_json, seller_name: "MegaStore", seller_product_id: "001",
        outcome: "pending_review", reason: "candidate_review", review_case: review_case)
      review_case.update!(status: "resolved")

      expect(row.reload.outcome).to eq("pending_review")
      expect(row.review_case.reload.status).to eq("resolved")
      expect { row.update!(outcome: "already_imported") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "rejects duplicate positions at the database level" do
      Intake::Models::RowResult.create!(batch: batch, source_position: 1, input_json: "null",
        outcome: "failed", reason: "invalid")

      expect do
        Intake::Models::RowResult.insert_all!([ { batch_id: batch.id, source_position: 1,
          input_json: "{}", outcome: "failed", reason: "invalid", created_at: Time.current } ])
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects position zero through both model validation and the database" do
      invalid = Intake::Models::RowResult.new(batch: batch, source_position: 0,
        input_json: "null", outcome: "failed", reason: "invalid")

      expect(invalid).not_to be_valid
      expect(invalid.errors[:source_position]).to be_present
      expect do
        Intake::Models::RowResult.transaction(requires_new: true) do
          Intake::Models::RowResult.insert_all!([ { batch_id: batch.id, source_position: 0,
            input_json: "null", outcome: "failed", reason: "invalid", created_at: Time.current } ])
        end
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "exact seller identity and review versions" do
    it "uses exact key strings and keeps source identity separate from corrections" do
      correction = Intake::Models::ReviewCorrection.create!(review_case: review_case, reviewer: "Alex",
        corrected_input: source_input.merge("Name" => "Camera Pro"),
        corrected_comparison: comparison.merge("name" => "camera pro"), corrected_at: Time.current)
      other = Intake::Models::SellerItem.create!(seller_name: "megastore", seller_product_id: "001",
        active_source_input: source_input, active_source_comparison: comparison, resolution: "pending")

      expect(Intake::Models::SellerItem.find_exact(seller_name: "MegaStore", seller_product_id: "001")).to eq(seller_item)
      expect(other).not_to eq(seller_item)
      expect(seller_item.reload.active_source_comparison).to eq(comparison)
      expect(review_case.reload.source_input).to eq(source_input)
      expect(correction.reload.corrected_comparison["name"]).to eq("camera pro")
      expect { correction.update!(reviewer: "Other") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "enforces at most one active case for a seller key and retains superseded history" do
      original = review_case
      expect do
        Intake::Models::ReviewCase.transaction(requires_new: true) do
          Intake::Models::ReviewCase.insert_all!([ { seller_item_id: seller_item.id, batch_id: batch.id,
            source_position: 2, status: "pending", reason: "changed_source", source_input: source_input,
            source_comparison: comparison, created_at: Time.current, updated_at: Time.current } ])
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)

      original.update!(status: "superseded")
      current = Intake::Models::ReviewCase.create!(seller_item: seller_item, batch: batch, source_position: 2,
        status: "pending", reason: "changed_source", source_input: source_input.merge("Name" => "New"),
        source_comparison: comparison.merge("name" => "new"))
      expect(seller_item.active_case).to eq(current)
      expect(original.reload.status).to eq("superseded")
    end

    it "rolls back supersession when the replacement case fails" do
      original = review_case

      expect do
        Intake::Models::ReviewCase.transaction do
          original.update!(status: "superseded")
          Intake::Models::ReviewCase.create!(seller_item: seller_item, batch: batch, source_position: 0,
            status: "pending", reason: "changed_source", source_input: source_input,
            source_comparison: comparison)
        end
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(original.reload.status).to eq("pending")
    end

    it "keeps the current product reference while changed source awaits review" do
      product = FactoryBot.create(:catalog_product)
      seller_item.update!(product_id: product.id)

      expect(seller_item.reload.resolution).to eq("pending")
      expect(seller_item.product_id).to eq(product.id)
      expect(review_case.reload.status).to eq("pending")
    end
  end

  describe "evidence and decision history" do
    let(:product) { FactoryBot.create(:catalog_product) }

    it "keeps rejected candidate evidence across later revisions" do
      review_case.update!(evidence_revision: 1)
      candidate = Intake::Models::ReviewCandidate.create!(review_case: review_case, product_id: product.id,
        evidence_revision: 1, rank: 1, score: 0.82, original: { "name" => product.name },
        comparison: comparison, differing_fields: [ "name" ])
      rejection = Intake::Models::ReviewRejection.create!(review_candidate: candidate,
        reviewer: "Alex", reason: "different variant", rejected_at: Time.current)
      review_case.update!(evidence_revision: 2)
      next_product = FactoryBot.create(:catalog_product)
      next_candidate = Intake::Models::ReviewCandidate.create!(review_case: review_case, product_id: next_product.id,
        evidence_revision: 2, rank: 1, score: 0.9, original: { "name" => next_product.name },
        comparison: comparison, differing_fields: [ "name" ])

      expect(rejection.reload.review_candidate).to eq(candidate)
      expect(candidate.reload.evidence_revision).to eq(1)
      expect(review_case.review_candidates.where(evidence_revision: 2).order(:rank)).to eq([ next_candidate ])
      expect(review_case.review_candidates.joins(:review_rejection).pluck(:product_id)).to eq([ product.id ])
      expect(next_candidate.review_rejection).to be_nil
      expect { rejection.update!(reason: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { candidate.update!(score: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "retains an unlinked declined identity with its final decision" do
      seller_item.update!(resolution: "declined")
      review_case.update!(status: "resolved")
      decision = Intake::Models::ReviewDecision.create!(review_case: review_case,
        reviewer: "Alex", result: "kept_existing", reason: "keep original listing",
        product_id: product.id, declined_seller_item_id: seller_item.id, decided_at: Time.current)

      expect(seller_item.reload.product_id).to be_nil
      expect(seller_item.resolution).to eq("declined")
      expect(decision.reload.declined_seller_item_id).to eq(seller_item.id)
      expect(review_case.reload.review_decision).to eq(decision)
    end

    it "retains the displaced seller key on a resolving decision" do
      displaced = Intake::Models::SellerItem.create!(seller_name: "MegaStore", seller_product_id: "old",
        active_source_input: source_input.merge("Id" => "old"), active_source_comparison: comparison,
        resolution: "linked", product_id: product.id)
      decision = Intake::Models::ReviewCase.transaction do
        displaced.update!(resolution: "displaced", product_id: nil)
        seller_item.update!(resolution: "linked", product_id: product.id)
        review_case.update!(status: "resolved")
        Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
          result: "linked", product_id: product.id, displaced_seller_item_id: displaced.id, decided_at: Time.current)
      end

      expect(Intake::Models::SellerItem.find(decision.reload.displaced_seller_item_id).seller_product_id).to eq("old")
      expect(displaced.reload.active_source_comparison).to eq(comparison)
      expect(displaced.resolution).to eq("displaced")
      expect(displaced.product_id).to be_nil
      expect(seller_item.reload.product_id).to eq(product.id)
      expect(review_case.reload.status).to eq("resolved")
    end

    it "does not permit editing or destroying a persisted decision through the model" do
      decision = Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", product_id: product.id, decided_at: Time.current)

      expect { decision.update!(reviewer: "Other") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { decision.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(decision.reload.reviewer).to eq("Alex")
    end

    it "blocks instance deletion of every historical record" do
      row = Intake::Models::RowResult.create!(batch: batch, source_position: 1, input_json: "null",
        outcome: "failed", reason: "invalid")
      review_case.update!(evidence_revision: 1)
      candidate = Intake::Models::ReviewCandidate.create!(review_case: review_case, product_id: product.id,
        evidence_revision: 1, rank: 1, score: 0.82, original: { "name" => product.name },
        comparison: comparison, differing_fields: [ "name" ])
      rejection = Intake::Models::ReviewRejection.create!(review_candidate: candidate,
        reviewer: "Alex", reason: "different variant", rejected_at: Time.current)
      correction = Intake::Models::ReviewCorrection.create!(review_case: review_case, reviewer: "Alex",
        corrected_input: source_input, corrected_comparison: comparison, corrected_at: Time.current)
      decision = Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", product_id: product.id, decided_at: Time.current)

      [ row, candidate, rejection, correction, decision ].each do |record|
        expect { record.delete }.to raise_error(ActiveRecord::ReadOnlyRecord)
        expect(record.reload).to be_persisted
      end
    end

    it "rejects a second final decision for one case at the database level" do
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", product_id: product.id, decided_at: Time.current)

      expect do
        Intake::Models::ReviewDecision.transaction(requires_new: true) do
          Intake::Models::ReviewDecision.insert_all!([ { review_case_id: review_case.id, reviewer: "Other",
            result: "linked", product_id: product.id, decided_at: Time.current } ])
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "protects historical product references with a database foreign key" do
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", product_id: product.id, decided_at: Time.current)

      expect do
        Catalog::Models::Product.transaction(requires_new: true) do
          Catalog::Models::Product.where(id: product.id).delete_all
        end
      end.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(product.reload).to be_persisted
    end

    it "protects a displaced seller identity referenced by a historical decision" do
      displaced = Intake::Models::SellerItem.create!(seller_name: "MegaStore", seller_product_id: "old",
        active_source_input: source_input.merge("Id" => "old"), active_source_comparison: comparison,
        resolution: "displaced")
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", product_id: product.id, displaced_seller_item_id: displaced.id, decided_at: Time.current)

      expect do
        Intake::Models::SellerItem.transaction(requires_new: true) do
          Intake::Models::SellerItem.where(id: displaced.id).delete_all
        end
      end.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(displaced.reload).to be_persisted
    end
  end
end
