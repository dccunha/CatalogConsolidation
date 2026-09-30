require "rails_helper"

RSpec.describe "Integrated acceptance journeys", type: :model do
  def import(*rows)
    Intake::Services::ImportProcessor.call(json: rows.to_json, source_name: "acceptance.json")
  end

  def current_candidate(review_case, product)
    review_case.review_candidates.where(evidence_revision: review_case.evidence_revision,
      product_id: product.id).sole
  end

  def seller_row(id:, name:, brand: "Canon", category: "Photo", seller: "Journey Seller")
    { "Id" => id, "SellerName" => seller, "Name" => name, "Brand" => brand, "Category" => category }
  end

  it "loads the reference into a clean catalog and reconciles all 269 supplied rows on two runs" do
    expect([ Catalog::Models::Product.count, Intake::Models::Batch.count ]).to eq([ 0, 0 ])
    reference_count = Catalog::Services::ReferenceCatalogLoader.call
    expect(Catalog::Models::Product.count).to eq(reference_count)
    json = File.read(Rails.root.join("docs/refs/ProductEntry.json"))

    first = Intake::Services::ImportProcessor.call(json: json, source_name: "ProductEntry.json")
    before_rerun = [ Catalog::Models::Product.count, Catalog::Models::SellerProduct.count,
      Intake::Models::SellerItem.count, Intake::Models::ReviewCase.count ]
    second = Intake::Services::ImportProcessor.call(json: json, source_name: "ProductEntry.json")

    [ first, second ].each do |result|
      expect(result.input_count).to eq(269)
      expect(result.rows.map(&:position)).to eq((1..269).to_a)
      expect(result.totals.values.sum).to eq(269)
      expect(Intake::Models::RowResult.where(batch_id: result.batch_id).count).to eq(269)
      expect(Intake::Services::ImportProcessor.fetch(batch_id: result.batch_id).totals).to eq(result.totals)
    end
    expect([ first.rows[0].outcome, first.rows[0].product_id ]).to eq([ "linked", 2 ])
    expect(first.rows[53].outcome).to eq("pending_review")
    expect(first.rows[87].outcome).to eq("pending_review")
    flagged_source = JSON.parse(json)[180]
    flagged = Intake::Models::RowResult.find_by!(batch_id: first.batch_id, source_position: 181)
    expect(flagged).to have_attributes(outcome: "failed", product_id: nil, review_case_id: nil)
    expect(flagged.reason).to include("Brand", "semicolon")
    expect(JSON.parse(flagged.input_json)).to eq(flagged_source)
    expect(Intake::Models::SellerItem.where(seller_name: flagged_source.fetch("SellerName"),
      seller_product_id: flagged_source.fetch("Id"))).to be_empty
    expect(Catalog::Models::Product.where(brand: flagged_source.fetch("Brand"))).to be_empty
    expect(Catalog::Models::SellerProduct.where(seller_name: flagged_source.fetch("SellerName"),
      seller_product_id: flagged_source.fetch("Id"))).to be_empty
    canon_case = Intake::Models::ReviewCase.find(first.rows[87].review_case_id)
    expect(canon_case.review_candidates.first.differing_fields).to include("category")
    expect(second.rows[53].review_case_id).to eq(first.rows[53].review_case_id)
    expect(second.rows[87].review_case_id).to eq(first.rows[87].review_case_id)
    expect(second.rows[180].outcome).to eq("failed")
    expect(second.totals.values_at("linked", "created")).to eq([ 0, 0 ])
    expect([ Catalog::Models::Product.count, Catalog::Models::SellerProduct.count,
      Intake::Models::SellerItem.count, Intake::Models::ReviewCase.count ]).to eq(before_rerun)
    expect(first.rows[53].review_case_id).to eq(
      Intake::Models::RowResult.find_by!(batch_id: first.batch_id, source_position: 54).review_case_id
    )
  end

  it "continues after invalid input, keeps incomplete metadata pending, and separates material variants" do
    exact = FactoryBot.create(:catalog_product, name: "Cable Organizer Kit", brand: "Acme", category: "Home")
    first = seller_row(id: "variant-128", name: "Phone X 128GB", brand: "Acme", category: "Electronics")
    variant = first.merge("Id" => "variant-256", "Name" => "Phone X 256GB")
    incomplete = seller_row(id: "incomplete", name: exact.name, brand: nil, category: exact.category)
    quoted = seller_row(id: "x'; DROP TABLE products; --", name: "Unlisted Widget'; DELETE FROM products; --",
      brand: "Safe", category: "Tools", seller: "O'Reilly")

    result = import(first, 42, incomplete, variant, quoted)

    expect(result.rows.map(&:position)).to eq([ 1, 2, 3, 4, 5 ])
    expect(result.rows.map(&:outcome)).to eq(%w[created failed pending_review created failed])
    expect(result.rows[1].reason).to include("JSON object")
    expect(result.rows[2].review_case_id).to be_present
    expect(result.rows[3].product_id).not_to eq(result.rows[0].product_id)
    expect(result.rows[4].reason).to include("Id", "Name", "prohibited")
    expect(Catalog::Models::Product.where(name: quoted.fetch("Name"))).to be_empty
    expect(result.totals.values.sum).to eq(5)
    expect(Intake::Models::RowResult.where(batch_id: result.batch_id).order(:source_position).pluck(:outcome))
      .to eq(result.rows.map(&:outcome))
  end

  it "corrects and approves a case, retains its original-source decision, then explicitly reassigns a changed identity" do
    first_product = FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon",
      category: "Photography")
    row = seller_row(id: "review-1", name: "Canon Camera")
    first = import(row)
    review_case = Intake::Models::ReviewCase.find(first.rows.sole.review_case_id)
    original_result = Intake::Models::RowResult.find_by!(batch_id: first.batch_id, source_position: 1)

    correction = Intake::Services::ReviewActions.correct(review_case_id: review_case.id,
      evidence_revision: 1, name: "Canon Camera", brand: "Canon", category: "Photography")
    expect(correction.status).to eq(:corrected)
    expect(review_case.reload.status).to eq("pending")
    expect(import(row).rows.sole.review_case_id).to eq(review_case.id)
    candidate = current_candidate(review_case, first_product)
    approval = Intake::Services::ReviewActions.approve(review_case_id: review_case.id,
      candidate_id: candidate.id, evidence_revision: review_case.evidence_revision)
    expect(approval.status).to eq(:approved)
    expect(import(row).rows.sole).to have_attributes(outcome: "already_imported", product_id: first_product.id)
    expect(original_result.reload.outcome).to eq("pending_review")

    target = FactoryBot.create(:catalog_product, name: "Canon Camera Mark II", brand: "Canon",
      category: "Photo")
    changed = row.merge("Name" => target.name)
    changed_result = import(changed).rows.sole
    changed_case = Intake::Models::ReviewCase.find(changed_result.review_case_id)
    expect(changed_result.outcome).to eq("pending_review")
    expect(Catalog::Models::SellerProduct.sole.product_id).to eq(first_product.id)
    selected = current_candidate(changed_case, target)
    move = Intake::Services::ReviewActions.reassign_candidate(review_case_id: changed_case.id,
      candidate_id: selected.id, evidence_revision: changed_case.evidence_revision)
    expect(move.status).to eq(:approved)
    expect(Catalog::Models::SellerProduct.sole.product_id).to eq(target.id)
    expect(import(changed).rows.sole).to have_attributes(outcome: "already_imported", product_id: target.id)
    expect(import(row).rows.sole.outcome).to eq("pending_review")
    expect(changed_case.reload.status).to eq("superseded")
    expect(Intake::Services::ReviewActions.reassign_candidate(review_case_id: changed_case.id,
      candidate_id: selected.id, evidence_revision: changed_case.evidence_revision).status).to eq(:not_actionable)
    expect(original_result.reload.outcome).to eq("pending_review")
  end

  it "requires another decision when a new candidate appears after every old candidate was rejected" do
    row = seller_row(id: "reject-1", name: "Canon Camera")
    old_product = FactoryBot.create(:catalog_product, name: row.fetch("Name"), brand: "Canon",
      category: "Photography")
    first = import(row)
    review_case = Intake::Models::ReviewCase.find(first.rows.sole.review_case_id)
    old_candidate = current_candidate(review_case, old_product)
    expect(Intake::Services::ReviewActions.reject(review_case_id: review_case.id,
      candidate_id: old_candidate.id, evidence_revision: 1, reason: "Different edition").status).to eq(:rejected)
    expect(Intake::Services::ReviewActions.creation_state(review_case: review_case)).to eq(:ready)
    new_product = FactoryBot.create(:catalog_product, name: row.fetch("Name"), brand: "Canon",
      category: "Electronics")

    expect(Intake::Services::ReviewActions.create(review_case_id: review_case.id,
      evidence_revision: 1).status).to eq(:stale)
    expect(review_case.reload.evidence_revision).to eq(2)
    expect(Intake::Services::ReviewActions.creation_state(review_case: review_case)).to eq(:candidates)
    expect(review_case.review_candidates.joins(:review_rejection).pluck(:product_id)).to eq([ old_product.id ])
    expect(Intake::Services::ReviewActions.create(review_case_id: review_case.id,
      evidence_revision: 2).status).to eq(:invalid)
    expect(Catalog::Models::SellerProduct.count).to eq(0)
    expect(current_candidate(review_case, new_product)).to be_present
  end
end
