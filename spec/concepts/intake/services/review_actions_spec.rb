require "rails_helper"

RSpec.describe Intake::Services::ReviewActions, type: :model do
  let(:source) do
    { "Id" => "review-1", "SellerName" => "Review Seller", "Name" => "Canon Camera",
      "Brand" => "Canon", "Category" => "Photo" }
  end
  let!(:product) do
    FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon", category: "Photography")
  end

  def import(row = source)
    Intake::Services::ImportProcessor.call(json: [ row ].to_json, source_name: "review.json")
  end

  def review_case
    @review_case ||= Intake::Models::ReviewCase.order(:id).last
  end

  def candidate
    review_case.review_candidates.where(evidence_revision: review_case.evidence_revision).order(:rank).first
  end

  def approve(selected = candidate, revision: review_case.evidence_revision)
    described_class.approve(review_case_id: review_case.id, candidate_id: selected.id, evidence_revision: revision)
  end

  describe "legacy unsafe pending cases" do
    it "refuses decisions while preserving the case, then accepts a safe correction" do
      import
      Intake::Models::ReviewCase.where(id: review_case.id)
        .update_all(source_input: source.merge("Name" => "Canon Camera; SELECT 1"))
      review_case.reload
      selected = candidate

      expect(described_class.creation_state(review_case: review_case)).to eq(:invalid_input)
      blocked = approve(selected)
      expect(blocked).to have_attributes(status: :invalid)
      expect(blocked.message).to include("Name", "semicolon")
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(review_case.reload.status).to eq("pending")
      expect(Intake::Models::ReviewDecision.count).to eq(0)

      bad = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Canon Camera--", brand: "Canon", category: "Photography")
      expect(bad.status).to eq(:invalid)
      expect(bad.message).to include("Name", "SQL line comment")
      expect(Intake::Models::ReviewCorrection.count).to eq(0)

      corrected = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Canon Camera", brand: "Canon", category: "Photography")
      expect(corrected.status).to eq(:corrected)
      expect(described_class.creation_state(review_case: review_case.reload)).not_to eq(:invalid_input)
      expect(review_case.review_corrections.sole.corrected_input.fetch("Name")).to eq("Canon Camera")
    end

    it "requires a new import when the legacy seller key is unsafe" do
      import
      Intake::Models::ReviewCase.where(id: review_case.id).update_all(source_input: source.merge("Id" => "bad;id"))
      review_case.reload

      expect(described_class.creation_state(review_case: review_case)).to eq(:invalid_input)
      result = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Canon Camera", brand: "Canon", category: "Photography")
      expect(result.status).to eq(:invalid)
      expect(result.message).to include("Id", "semicolon")
      expect(Intake::Models::ReviewCorrection.count).to eq(0)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
    end
  end

  describe ".approve" do
    it "approves a stable non-exact candidate without endlessly refreshing its rounded score" do
      import(source.merge("Name" => "Canon Cameras"))
      selected = candidate
      expect(selected.score).to be_between(0.8, 1.0).exclusive

      result = approve(selected)

      expect(result.status).to eq(:approved)
      expect(review_case.reload.evidence_revision).to eq(1)
      expect(review_case.review_decision.product_id).to eq(product.id)
    end

    it "links only the selected product, saves the reviewer decision, and replays an unchanged rerun" do
      import
      original_attributes = product.attributes

      result = approve

      expect(result.status).to eq(:approved)
      expect(review_case.reload.status).to eq("resolved")
      expect(review_case.review_decision.attributes).to include("result" => "linked", "product_id" => product.id,
        "reviewer" => Intake::Reviewer.name)
      expect(review_case.review_decision.decided_at).to be_present
      expect(Catalog::Models::SellerProduct.find_by!(seller_name: source.fetch("SellerName"),
        seller_product_id: source.fetch("Id")).product_id).to eq(product.id)
      expect(product.reload.attributes).to eq(original_attributes)

      rerun = import
      expect(rerun.rows.sole.outcome).to eq("already_imported")
      expect(rerun.rows.sole.product_id).to eq(product.id)
      expect(rerun.rows.sole.reason).to include("retained linked decision")
      expect(Intake::Models::ReviewDecision.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(1)
    end

    it "rolls back the Catalog association if the decision insert fails" do
      import
      allow(Intake::Models::ReviewDecision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { approve }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(review_case.reload.status).to eq("pending")
      expect(review_case.seller_item.reload).to have_attributes(resolution: "pending", product_id: nil)
      expect(Intake::Models::ReviewDecision.count).to eq(0)
    end

    it "refreshes changed Catalog evidence and refuses an approval from the old page" do
      import
      old_candidate = candidate
      product.update!(category: "Video")

      result = approve(old_candidate)

      expect(result.status).to eq(:stale)
      expect(review_case.reload.evidence_revision).to eq(2)
      expect(review_case.review_candidates.where(evidence_revision: 2).sole.original.fetch("category")).to eq("Video")
      expect(review_case.status).to eq("pending")
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(described_class.approve(review_case_id: review_case.id, candidate_id: old_candidate.id,
        evidence_revision: 1).status).to eq(:stale)
    end

    it "rejects a repeated approval and a superseded case" do
      import
      old_candidate = candidate
      expect(approve.status).to eq(:approved)
      expect(approve(old_candidate).status).to eq(:not_actionable)

      changed = import(source.merge("Name" => "Canon Camera Mark II"))
      expect(changed.rows.sole.outcome).to eq("pending_review")
      expect(approve(old_candidate).status).to eq(:not_actionable)
      expect(Intake::Models::ReviewDecision.count).to eq(1)
    end

    it "leaves changed-source reassignment and same-seller conflicts for the later command" do
      Catalog::Models::SellerProduct.create!(seller_name: source.fetch("SellerName"),
        seller_product_id: "other-id", product_id: product.id)
      import

      expect(approve.status).to eq(:conflict)
      expect(review_case.reload.status).to eq("pending")
      expect(Intake::Models::ReviewDecision.count).to eq(0)
    end

    it "refreshes evidence when a same-seller association appears before submission" do
      import
      selected = candidate
      Catalog::Models::SellerProduct.create!(seller_name: source.fetch("SellerName"),
        seller_product_id: "other-id", product_id: product.id)

      expect(approve(selected).status).to eq(:stale)
      expect(review_case.reload.evidence_revision).to eq(2)
      expect(review_case.conflicting_association).to include("seller_product_id" => "other-id")
      expect(review_case.status).to eq("pending")
      expect(Intake::Models::ReviewDecision.count).to eq(0)
    end
  end

  describe ".reject" do
    it "rejects a stable non-exact candidate without refreshing its rounded score" do
      import(source.merge("Name" => "Canon Cameras"))
      selected = candidate
      expect(selected.score).to be_between(0.8, 1.0).exclusive

      result = described_class.reject(review_case_id: review_case.id, candidate_id: selected.id,
        evidence_revision: 1, reason: "Wrong model")

      expect(result.status).to eq(:rejected)
      expect(review_case.reload.evidence_revision).to eq(1)
      expect(selected.review_rejection.reload.reason).to eq("Wrong model")
    end

    it "records individual reasons, retains rejections after rematching, and never creates a product" do
      other = FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon", category: "Video")
      import
      first, second = review_case.review_candidates.order(:rank).to_a

      first_result = described_class.reject(review_case_id: review_case.id, candidate_id: first.id,
        evidence_revision: 1, reason: "Wrong edition")
      second_result = described_class.reject(review_case_id: review_case.id, candidate_id: second.id,
        evidence_revision: 1, reason: "Wrong category")

      expect(first_result.status).to eq(:rejected)
      expect(second_result.status).to eq(:rejected)
      expect(review_case.review_candidates.joins(:review_rejection).order(:rank).pluck(:product_id)).to eq([ product.id, other.id ])
      expect(Intake::Models::ReviewRejection.order(:id).pluck(:reviewer, :reason)).to eq([
        [ Intake::Reviewer.name, "Wrong edition" ], [ Intake::Reviewer.name, "Wrong category" ]
      ])
      expect(review_case.reload.status).to eq("pending")
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(Catalog::Models::Product.count).to eq(2)
      expect(import.rows.sole).to have_attributes(outcome: "pending_review", review_case_id: review_case.id)
      expect(Intake::Models::ReviewRejection.count).to eq(2)

      correction = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Canon Camera", brand: "Canon", category: "Photography")
      expect(correction.status).to eq(:corrected)
      refreshed = review_case.reload.review_candidates.where(evidence_revision: 2).find_by!(product_id: product.id)
      expect(described_class.approve(review_case_id: review_case.id, candidate_id: refreshed.id,
        evidence_revision: 2).status).to eq(:invalid)
      expect(Intake::Models::ReviewRejection.count).to eq(2)
    end

    it "requires a reason and refuses repeated or old-revision rejection" do
      import
      selected = candidate
      expect(described_class.reject(review_case_id: review_case.id, candidate_id: selected.id,
        evidence_revision: 1, reason: "  ").status).to eq(:invalid)
      expect(described_class.reject(review_case_id: review_case.id, candidate_id: selected.id,
        evidence_revision: 1, reason: "Not this model").status).to eq(:rejected)
      expect(described_class.reject(review_case_id: review_case.id, candidate_id: selected.id,
        evidence_revision: 1, reason: "Again").status).to eq(:invalid)
      expect(Intake::Models::ReviewRejection.count).to eq(1)
    end

    it "refreshes a stale candidate before recording a rejection" do
      import
      selected = candidate
      product.update!(category: "Video")

      result = described_class.reject(review_case_id: review_case.id, candidate_id: selected.id,
        evidence_revision: 1, reason: "Wrong category")

      expect(result.status).to eq(:stale)
      expect(review_case.reload.evidence_revision).to eq(2)
      expect(Intake::Models::ReviewRejection.count).to eq(0)
    end
  end

  describe ".correct" do
    it "keeps corrected exact evidence pending and the original tuple stable across a rerun" do
      import
      result = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Canon Camera", brand: "Canon", category: "Photography")

      expect(result.status).to eq(:corrected)
      expect(review_case.reload).to have_attributes(status: "pending", evidence_revision: 2)
      expect(review_case.source_input).to eq(source)
      expect(review_case.review_corrections.sole.corrected_input).to include("Id" => source.fetch("Id"),
        "SellerName" => source.fetch("SellerName"), "Category" => "Photography")
      expect(review_case.review_corrections.sole.reviewer).to eq(Intake::Reviewer.name)
      expect(review_case.review_candidates.where(evidence_revision: 2).sole.differing_fields).to eq([])

      rerun = import
      expect(rerun.rows.sole).to have_attributes(outcome: "pending_review", review_case_id: review_case.id)
      expect(Intake::Models::ReviewCase.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
    end

    it "keeps a no-candidate correction pending without changing its source identity" do
      import
      result = described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: "Unknown camera", brand: "Other brand", category: "Unlisted")

      expect(result.status).to eq(:corrected)
      expect(review_case.reload.status).to eq("pending")
      expect(review_case.review_candidates.where(evidence_revision: 2)).to be_empty
      expect(review_case.source_comparison.fetch("name")).to eq("canon camera")
      expect(import.rows.sole.outcome).to eq("pending_review")
      expect(Catalog::Models::Product.count).to eq(1)
    end

    it "rejects invalid input and an old evidence revision without a correction write" do
      import
      expect(described_class.correct(review_case_id: review_case.id, evidence_revision: 1,
        name: " ", brand: "Canon", category: "Photo").status).to eq(:invalid)
      expect(described_class.correct(review_case_id: review_case.id, evidence_revision: 0,
        name: "New name", brand: "Canon", category: "Photo").status).to eq(:stale)
      expect(Intake::Models::ReviewCorrection.count).to eq(0)
    end
  end
end
