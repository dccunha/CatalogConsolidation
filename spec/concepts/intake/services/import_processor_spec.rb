require "rails_helper"

RSpec.describe Intake::Services::ImportProcessor, type: :model do
  let(:row) do
    { "Id" => "001", "SellerName" => "MegaStore", "Name" => "Smartphone Galaxy S23",
      "Brand" => "Samsung", "Category" => "Electronics" }
  end

  def import(*rows, source_name: "seller.json")
    described_class.call(json: rows.to_json, source_name: source_name)
  end

  def expect_reconciled(result)
    expect(result.totals.values.sum).to eq(result.input_count)
    expect(result.rows.map(&:position)).to eq((1..result.input_count).to_a)
    expect(Intake::Models::RowResult.where(batch_id: result.batch_id).count).to eq(result.input_count)
  end

  describe ".call" do
    it "rejects malformed JSON and a non-array before creating a batch" do
      expect { described_class.call(json: "[{", source_name: "bad.json") }
        .to raise_error(described_class::FileError, /malformed JSON/)
      expect { described_class.call(json: '{}', source_name: "object.json") }
        .to raise_error(described_class::FileError, /JSON array/)
      expect(Intake::Models::Batch.count).to eq(0)
    end

    it "accepts an empty array with zero results and reconciled totals" do
      result = import

      expect(result.totals).to eq("linked" => 0, "created" => 0, "already_imported" => 0,
        "pending_review" => 0, "failed" => 0)
      expect_reconciled(result)
    end

    it "links the Galaxy row to reference product 2 without changing its catalog attributes" do
      Catalog::Services::ReferenceCatalogLoader.call
      product = Catalog::Models::Product.find(2)
      before = product.attributes.slice("name", "brand", "category")

      result = import(row)

      expect([ result.rows.first.outcome, result.rows.first.product_id ]).to eq([ "linked", 2 ])
      expect(result.rows.first.reason).to include("exact catalog product 2")
      expect(Catalog::Models::SellerProduct.find_by!(seller_name: "MegaStore", seller_product_id: "001").product_id).to eq(2)
      expect(product.reload.attributes.slice("name", "brand", "category")).to eq(before)
      expect_reconciled(result)
    end

    it "creates a complete unmatched product and allows a later row to link to that live product" do
      second = row.merge("Id" => "002", "SellerName" => "OtherSeller")

      result = import(row, second)

      expect(result.rows.map(&:outcome)).to eq(%w[created linked])
      expect(result.rows.map(&:product_id).uniq.length).to eq(1)
      expect(Catalog::Models::Product.where(name: row["Name"]).count).to eq(1)
      expect(Catalog::Models::SellerProduct.where(product_id: result.rows.first.product_id).count).to eq(2)
      expect_reconciled(result)
    end

    it "reports exact outcome totals and reconstructs a mixed nonempty batch" do
      FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      created = row.merge("Id" => "002", "Name" => "Unlisted desk lamp", "Brand" => "BrightCo", "Category" => "Home")
      pending = row.merge("Id" => "003", "Name" => "Cable Organizer Kit", "Brand" => nil)

      result = import(row, created, pending, 17)
      fetched = described_class.fetch(batch_id: result.batch_id)

      expect(result.totals).to eq("linked" => 1, "created" => 1, "already_imported" => 0,
        "pending_review" => 1, "failed" => 1)
      expect(result.rows.map(&:outcome)).to eq(%w[linked created pending_review failed])
      expect(result.rows.map(&:position)).to eq([ 1, 2, 3, 4 ])
      expect(fetched.totals).to eq(result.totals)
      expect(fetched.rows.map(&:serialize)).to eq(result.rows.map(&:serialize))
      expect(Intake::Models::RowResult.where(batch_id: result.batch_id).group(:outcome).count).to eq(
        "linked" => 1, "created" => 1, "pending_review" => 1, "failed" => 1
      )
      expect_reconciled(result)
    end

    it "holds incomplete metadata and persists ranked candidate evidence" do
      product = FactoryBot.create(:catalog_product, name: "Cable Organizer Kit", brand: "Acme", category: "Home")
      pending = row.merge("Name" => "Cable Organizer Kit", "Brand" => nil, "Category" => "Home")

      result = import(pending)
      review_case = Intake::Models::ReviewCase.find(result.rows.first.review_case_id)
      candidate = review_case.review_candidates.sole

      expect([ result.rows.first.outcome, review_case.status ]).to eq([ "pending_review", "pending" ])
      expect(review_case.reason).to include("incomplete metadata")
      expect([ candidate.product_id, candidate.rank, candidate.evidence_revision ]).to eq([ product.id, 1, 1 ])
      expect(candidate.original).to eq("name" => product.name, "brand" => product.brand,
        "category" => product.category)
      expect(candidate.comparison).to eq("name" => "cable organizer kit", "brand" => "acme", "category" => "home")
      expect(Intake::Models::SellerItem.find_exact(seller_name: "MegaStore", seller_product_id: "001").resolution).to eq("pending")
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect_reconciled(result)
    end

    it "persists source and normalized identity with multiple ranked candidate snapshots" do
      exact = FactoryBot.create(:catalog_product, name: row["Name"],
        brand: row["Brand"], category: row["Category"])
      near = FactoryBot.create(:catalog_product, name: "Smartphone Galaxy S24",
        brand: row["Brand"], category: row["Category"])
      source = row.merge("Name" => " Smártphone  Galaxy S23 ", "Brand" => "SAMSUNG",
        "Category" => " Electronics ")

      result = import(source)
      review_case = Intake::Models::ReviewCase.find(result.rows.first.review_case_id)
      candidates = review_case.review_candidates.order(:rank).to_a

      expect(result.rows.first.outcome).to eq("pending_review")
      expect(review_case.reason).to include("additional candidates")
      expect(review_case.source_input).to eq(source)
      expect(review_case.source_comparison).to eq("name" => "smartphone galaxy s23",
        "brand" => "samsung", "category" => "electronics")
      expect(candidates.map { |candidate| [ candidate.rank, candidate.product_id, candidate.evidence_revision ] }).to eq(
        [ [ 1, exact.id, 1 ], [ 2, near.id, 1 ] ]
      )
      expect(candidates.first.score.to_f).to eq(1.0)
      expect(candidates.last.score.to_f).to be_between(0.8, 1.0).exclusive
      expect(candidates.map(&:differing_fields)).to eq([ [], [ "name" ] ])
      expect(candidates.map { |candidate| candidate.original["name"] }).to eq(
        [ "Smartphone Galaxy S23", "Smartphone Galaxy S24" ]
      )
      expect(candidates.map { |candidate| candidate.comparison["name"] }).to eq(
        [ "smartphone galaxy s23", "smartphone galaxy s24" ]
      )
      expect_reconciled(result)
    end

    it "holds incomplete metadata even without a catalog candidate" do
      incomplete = row.merge("Brand" => nil, "Name" => "Entirely new product")

      result = import(incomplete)

      expect([ result.rows.first.outcome, result.rows.first.product_id ]).to eq([ "pending_review", nil ])
      expect(Intake::Models::ReviewCase.find(result.rows.first.review_case_id).review_candidates.count).to eq(0)
      expect(Catalog::Models::Product.count).to eq(0)
      expect_reconciled(result)
    end

    it "persists a same-seller product conflict for review without changing its association" do
      product = FactoryBot.create(:catalog_product, name: row["Name"],
        brand: row["Brand"], category: row["Category"])
      existing = Catalog::Public::Writes.link(product_id: product.id, seller_name: "MegaStore", seller_product_id: "old")

      result = import(row)
      review_case = Intake::Models::ReviewCase.find(result.rows.first.review_case_id)

      expect(result.rows.first.outcome).to eq("pending_review")
      expect(review_case.conflicting_association).to include("id" => existing.id,
        "seller_product_id" => "old", "product_id" => product.id)
      expect(review_case.review_candidates.sole.conflicting_association).to eq(review_case.conflicting_association)
      expect(existing.reload.seller_product_id).to eq("old")
      expect_reconciled(result)
    end

    it "keeps invalid elements and missing required fields between successful rows" do
      second = row.merge("Id" => "002", "SellerName" => "OtherSeller", "Name" => "Different product")
      invalid = row.merge("Name" => nil)

      result = import(row, 17, invalid, second)
      stored = Intake::Models::RowResult.where(batch_id: result.batch_id).order(:source_position).to_a

      expect(result.rows.map(&:outcome)).to eq(%w[created failed failed created])
      expect(result.rows.map(&:position)).to eq([ 1, 2, 3, 4 ])
      expect(result.rows[1].reason).to include("JSON object")
      expect(result.rows[2].reason).to include("Name is required")
      expect(stored.map(&:input_json)).to eq([ row, 17, invalid, second ].map(&:to_json))
      expect(stored[1].validation_errors).to eq([ { "field" => nil, "code" => "not_an_object" } ])
      expect(stored[2].validation_errors).to eq([ { "field" => "Name", "code" => "required" } ])
      expect([ stored[2].seller_name, stored[2].seller_product_id ]).to eq([ "MegaStore", "001" ])
      expect_reconciled(result)
    end

    it "rolls back a failed Catalog write and continues with the next row" do
      allow(Catalog::Public::Writes).to receive(:create_with_association).and_wrap_original do |original, **attributes|
        original.call(**attributes).tap do
          raise "forced Catalog write failure" if attributes[:seller_product_id] == "001"
        end
      end
      later = row.merge("Id" => "002", "SellerName" => "OtherSeller", "Name" => "Later product")

      result = import(row, later)

      expect(result.rows.map(&:outcome)).to eq(%w[failed created])
      expect(result.rows.first.reason).to include("forced Catalog write failure")
      expect(Catalog::Models::Product.where(name: row["Name"]).count).to eq(0)
      expect(Catalog::Models::SellerProduct.where(seller_name: "MegaStore").count).to eq(0)
      expect(Intake::Models::RowResult.where(batch_id: result.batch_id, outcome: "failed").count).to eq(1)
      expect_reconciled(result)
    end

    it "rolls back a Catalog product and association when subsequent Intake persistence fails" do
      allow(Intake::Models::SellerItem).to receive(:create!).and_wrap_original do |original, **attributes|
        original.call(**attributes).tap do
          raise "forced Intake failure" if attributes[:seller_product_id] == "001"
        end
      end
      later = row.merge("Id" => "002", "SellerName" => "OtherSeller", "Name" => "Later product")

      result = import(row, later)

      expect(result.rows.map(&:outcome)).to eq(%w[failed created]), result.rows.map(&:reason).inspect
      expect(result.rows.first.reason).to include("forced Intake failure")
      expect(Catalog::Models::Product.where(name: row["Name"]).count).to eq(0)
      expect(Catalog::Models::SellerProduct.where(seller_name: "MegaStore").count).to eq(0)
      expect(Intake::Models::SellerItem.where(seller_name: "MegaStore").count).to eq(0)
      expect_reconciled(result)
    end

    it "retains a flagged source only in Intake and continues to the next row" do
      quoted = row.merge("Id" => "001'; DROP TABLE products; --",
        "SellerName" => "O'Reilly; DELETE FROM intake_batches; --",
        "Name" => "Widget'); DROP TABLE products; --")
      later = row.merge("Id" => "002", "SellerName" => "O'Reilly", "Name" => "Widget (safe)")

      result = import(quoted, later)

      expect(result.rows.map(&:outcome)).to eq(%w[failed created])
      expect(result.rows.first.reason).to include("Id", "SellerName", "Name", "prohibited")
      stored = Intake::Models::RowResult.find_by!(batch_id: result.batch_id, source_position: 1)
      expect(JSON.parse(stored.input_json)).to eq(quoted)
      expect(stored).to have_attributes(product_id: nil, review_case_id: nil, outcome: "failed")
      expect(Catalog::Models::Product.where(name: quoted["Name"])).to be_empty
      expect(Catalog::Models::SellerProduct.where(seller_name: quoted["SellerName"])).to be_empty
      expect(Intake::Models::SellerItem.where(seller_name: quoted["SellerName"])).to be_empty
      expect(Intake::Models::ReviewCase.count).to eq(0)
      expect(Intake::Models::Batch.find(result.batch_id).input_count).to eq(2)
      expect_reconciled(result)
    end

    it "rejects flagged rows again on rerun without restoring a seller item" do
      flagged = row.merge("Brand" => "BadBrand; SELECT 1 --")

      first = import(flagged)
      second = import(flagged)

      expect([ first.rows.sole.outcome, second.rows.sole.outcome ]).to eq(%w[failed failed])
      expect(Intake::Models::SellerItem.count).to eq(0)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect(Intake::Models::RowResult.where(outcome: "failed").count).to eq(2)
      expect_reconciled(second)
    end

    it "keeps control characters in Intake JSON without putting them in database seller-key columns" do
      flagged = row.merge("Id" => "unsafe\u0000id")

      result = import(flagged)

      stored = Intake::Models::RowResult.find_by!(batch_id: result.batch_id, source_position: 1)
      expect(result.rows.sole.outcome).to eq("failed")
      expect(stored.seller_product_id).to be_nil
      expect(JSON.parse(stored.input_json)).to eq(flagged)
      expect(Intake::Models::SellerItem.count).to eq(0)
    end
  end

  describe ".fetch" do
    it "reconstructs a complete report from immutable row results" do
      result = import(row)

      fetched = described_class.fetch(batch_id: result.batch_id)
      expect([ fetched.batch_id, fetched.input_count, fetched.totals ]).to eq(
        [ result.batch_id, result.input_count, result.totals ]
      )
      expect(fetched.rows.map(&:serialize)).to eq(result.rows.map(&:serialize))
    end

    it "rejects a batch with a gap even when its result count equals input count" do
      batch = Intake::Models::Batch.create!(source_name: "broken.json", input_count: 2, created_at: Time.current)
      [ 1, 3 ].each do |position|
        Intake::Models::RowResult.create!(batch: batch, source_position: position,
          input_json: "null", outcome: "failed", reason: "invalid")
      end

      expect { described_class.fetch(batch_id: batch.id) }.to raise_error(/Incomplete import batch/)
    end
  end

  describe "seller identity reruns" do
    it "uses the exact seller key and normalized source identity within and across batches" do
      equivalent = row.merge("Name" => "  SMARTPHONE   Galaxy S23  ",
        "Brand" => "SAMSUNG", "Category" => "  Electronics ")
      accented = row.merge("Name" => "Smartphoné Galaxy S23")
      distinct_key = row.merge("Id" => "001 ")

      first = import(row, equivalent, accented)
      second = import(accented, distinct_key)

      expect(first.rows.map(&:outcome)).to eq(%w[created already_imported already_imported])
      expect(second.rows.map(&:outcome)).to eq(%w[already_imported pending_review])
      expect(first.rows.map(&:product_id).uniq).to eq([ first.rows.first.product_id ])
      expect(Intake::Models::SellerItem.where(seller_name: "MegaStore").count).to eq(2)
      expect(Catalog::Models::SellerProduct.where(seller_name: "MegaStore", seller_product_id: "001").count).to eq(1)
      expect_reconciled(first)
      expect_reconciled(second)
    end

    it "reuses a pending case for repeated keys in a file and on another run" do
      incomplete = row.merge("Brand" => nil)

      first = import(incomplete, incomplete)
      second = import(incomplete)

      expect(first.rows.map(&:outcome)).to eq(%w[pending_review pending_review])
      expect(second.rows.first.outcome).to eq("pending_review")
      expect((first.rows + second.rows).map(&:review_case_id).uniq).to eq([ first.rows.first.review_case_id ])
      expect(Intake::Models::ReviewCase.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect_reconciled(first)
      expect_reconciled(second)
    end

    it "retains a final decision after review and an equivalent source rerun" do
      product = FactoryBot.create(:catalog_product)
      incomplete = row.merge("Brand" => nil)
      first = import(incomplete)
      review_case = Intake::Models::ReviewCase.find(first.rows.first.review_case_id)
      association = Catalog::Public::Writes.link(product_id: product.id,
        seller_name: "MegaStore", seller_product_id: "001")
      review_case.seller_item.update!(resolution: "linked", product_id: association.product_id)
      review_case.update!(status: "resolved")
      decision = Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", reason: "confirmed product", product_id: product.id, decided_at: Time.current)

      rerun = import(incomplete)

      expect(rerun.rows.first.outcome).to eq("already_imported")
      expect(rerun.rows.first.product_id).to eq(product.id)
      expect(rerun.rows.first.review_case_id).to eq(review_case.id)
      expect(rerun.rows.first.reason).to include("decision #{decision.id}", "confirmed product")
      expect(first.rows.first.outcome).to eq("pending_review")
      expect(Intake::Models::ReviewCase.count).to eq(1)
      expect(Catalog::Models::SellerProduct.count).to eq(1)
      expect_reconciled(rerun)
    end

    it "keeps original source identity after correction and opens review for a later change" do
      original = row.merge("Brand" => nil)
      first = import(original)
      review_case = Intake::Models::ReviewCase.find(first.rows.first.review_case_id)
      corrected = original.merge("Brand" => "Samsung")
      Intake::Models::ReviewCorrection.create!(review_case: review_case, reviewer: "Alex",
        corrected_input: corrected, corrected_comparison: { "name" => "smartphone galaxy s23",
          "brand" => "samsung", "category" => "electronics" }, corrected_at: Time.current)
      unchanged = import(original)
      product = FactoryBot.create(:catalog_product)
      association = Catalog::Public::Writes.link(product_id: product.id,
        seller_name: "MegaStore", seller_product_id: "001")
      review_case.seller_item.update!(resolution: "linked", product_id: association.product_id)
      review_case.update!(status: "resolved")
      decision = Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "linked", product_id: product.id, decided_at: Time.current)
      resolved = import(original)
      changed = import(corrected)

      expect(unchanged.rows.first.review_case_id).to eq(review_case.id)
      expect([ resolved.rows.first.outcome, resolved.rows.first.review_case_id ]).to eq(
        [ "already_imported", review_case.id ])
      expect(resolved.rows.first.reason).to include("decision #{decision.id}")
      expect(changed.rows.first.outcome).to eq("pending_review")
      expect(changed.rows.first.review_case_id).not_to eq(review_case.id)
      expect(review_case.reload.status).to eq("superseded")
      expect(review_case.seller_item.reload.active_source_input).to eq(corrected)
      expect(Intake::Models::ReviewCase.find(changed.rows.first.review_case_id).source_input).to eq(corrected)
      expect(Catalog::Models::SellerProduct.sole.product_id).to eq(product.id)
      expect_reconciled(changed)
    end

    it "supersedes successive changes and treats a historical reversion as a new version" do
      original = row.merge("Brand" => nil)
      second_source = original.merge("Name" => "Galaxy S23 Plus")
      third_source = original.merge("Name" => "Galaxy S23 Ultra")
      first = import(original)
      second = import(second_source)
      third = import(third_source)
      reverted = import(original)
      cases = Intake::Models::ReviewCase.order(:id).to_a

      expect([ first, second, third, reverted ].map { |result| result.rows.first.outcome }).to eq(
        %w[pending_review pending_review pending_review pending_review]
      )
      expect(cases.map(&:status)).to eq(%w[superseded superseded superseded pending])
      expect(cases.map(&:id)).to eq([ first, second, third, reverted ].map { |result| result.rows.first.review_case_id })
      expect(Intake::Models::SellerItem.sole.active_source_input).to eq(original)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect_reconciled(reverted)
    end

    it "preserves the current association while changing a resolved source" do
      first = import(row)
      product_id = first.rows.first.product_id
      changed = row.merge("Brand" => "Acme")

      second = import(changed, changed)
      seller_item = Intake::Models::SellerItem.sole
      review_case = Intake::Models::ReviewCase.sole
      association = Catalog::Models::SellerProduct.sole
      candidate = review_case.review_candidates.sole

      expect(second.rows.map(&:outcome)).to eq(%w[pending_review pending_review])
      expect(second.rows.map(&:review_case_id).uniq).to eq([ review_case.id ])
      expect(review_case.source_input).to eq(changed)
      expect(review_case.source_comparison).to eq(
        "name" => "smartphone galaxy s23", "brand" => "acme", "category" => "electronics")
      expect(review_case.reason).to include("changed source identity", "seller item taken", "candidate review")
      expect(review_case.conflicting_association).to include("id" => association.id,
        "product_id" => product_id, "seller_product_id" => "001")
      expect([ review_case.evidence_revision, candidate.evidence_revision, candidate.rank ]).to eq([ 1, 1, 1 ])
      expect([ candidate.product_id, candidate.score.to_f, candidate.differing_fields ]).to eq(
        [ product_id, 1.0, [ "brand" ] ])
      expect(candidate.original).to include("name" => row["Name"], "brand" => row["Brand"])
      expect(candidate.comparison).to include("brand" => "samsung")
      expect(seller_item.reload.product_id).to eq(product_id)
      expect(seller_item.resolution).to eq("pending")
      expect(association.reload.product_id).to eq(product_id)
      expect(first.rows.first.outcome).to eq("created")
      reverted = import(row)
      expect(reverted.rows.first.outcome).to eq("pending_review")
      expect(reverted.rows.first.review_case_id).not_to eq(review_case.id)
      expect(review_case.reload.status).to eq("superseded")
      expect(seller_item.reload.product_id).to eq(product_id)
      expect(Catalog::Models::SellerProduct.count).to eq(1)
      expect_reconciled(second)
      expect_reconciled(reverted)
    end

    it "rolls back supersession and source replacement when the new case cannot be saved" do
      original = row.merge("Brand" => nil)
      first = import(original)
      review_case = Intake::Models::ReviewCase.find(first.rows.first.review_case_id)
      allow(Intake::Models::ReviewCase).to receive(:create!).and_raise("forced case failure")

      failed = import(original.merge("Name" => "Changed"))

      expect(failed.rows.first.outcome).to eq("failed")
      expect(failed.rows.first.reason).to include("forced case failure")
      expect(review_case.reload.status).to eq("pending")
      expect(review_case.seller_item.reload.active_source_input).to eq(original)
      expect(Intake::Models::ReviewCase.count).to eq(1)
      expect_reconciled(failed)
    end

    it "retains declined and displaced decisions without relinking either seller key" do
      product = FactoryBot.create(:catalog_product)
      first = import(row.merge("Brand" => nil))
      review_case = Intake::Models::ReviewCase.find(first.rows.first.review_case_id)
      review_case.seller_item.update!(resolution: "declined")
      review_case.update!(status: "resolved")
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Alex",
        result: "kept_existing", reason: "keep original ID", product_id: product.id,
        declined_seller_item_id: review_case.seller_item.id, decided_at: Time.current)
      declined = import(row.merge("Brand" => nil))

      expect([ declined.rows.first.outcome, declined.rows.first.product_id ]).to eq([ "already_imported", nil ])
      expect(declined.rows.first.reason).to include("kept_existing", "without association")
      expect(Catalog::Models::SellerProduct.count).to eq(0)

      displaced_item = Intake::Models::SellerItem.create!(seller_name: "MegaStore", seller_product_id: "old",
        active_source_input: row.merge("Id" => "old", "Brand" => nil),
        active_source_comparison: review_case.source_comparison,
        resolution: "displaced")
      replacement_case = Intake::Models::ReviewCase.create!(seller_item: displaced_item,
        batch: Intake::Models::Batch.find(first.batch_id), source_position: 1, status: "resolved",
        reason: "listing replacement", source_input: displaced_item.active_source_input,
        source_comparison: displaced_item.active_source_comparison)
      Intake::Models::ReviewDecision.create!(review_case: replacement_case, reviewer: "Alex",
        result: "linked", product_id: product.id, displaced_seller_item_id: displaced_item.id,
        decided_at: Time.current)
      displaced = import(row.merge("Id" => "old", "Brand" => nil))

      expect([ displaced.rows.first.outcome, displaced.rows.first.product_id ]).to eq([ "already_imported", nil ])
      expect(displaced.rows.first.reason).to include("displaced", "without association")
      expect(Intake::Models::ReviewCase.count).to eq(2)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
      expect_reconciled(displaced)
    end

    it "records every supplied file position on two equivalent runs without duplicate keys or associations" do
      Catalog::Services::ReferenceCatalogLoader.call
      json = File.read(Rails.root.join("docs/refs/ProductEntry.json"))
      first = described_class.call(json: json, source_name: "ProductEntry.json")
      item_count = Intake::Models::SellerItem.count
      case_count = Intake::Models::ReviewCase.count
      association_count = Catalog::Models::SellerProduct.count
      second = described_class.call(json: json, source_name: "ProductEntry.json")

      expect(first.input_count).to eq(269)
      expect(second.input_count).to eq(269)
      expect(first.rows.map(&:position)).to eq((1..269).to_a)
      expect(second.rows.map(&:position)).to eq((1..269).to_a)
      expect([ first.rows[0].outcome, first.rows[0].product_id ]).to eq([ "linked", 2 ])
      expect(first.rows[53].outcome).to eq("pending_review")
      expect([ first.rows[55].outcome, first.rows[55].product_id ]).to eq([ "linked", 18 ])
      expect([ first.rows[76].outcome, first.rows[76].product_id ]).to eq([ "already_imported", 18 ])
      expect(first.rows[87].outcome).to eq("pending_review")
      expect(first.rows[180]).to have_attributes(outcome: "failed", product_id: nil, review_case_id: nil)
      expect(first.rows[180].reason).to include("Brand", "semicolon")
      expect([ second.rows[0].outcome, second.rows[0].product_id ]).to eq([ "already_imported", 2 ])
      expect([ second.rows[55].outcome, second.rows[55].product_id ]).to eq([ "already_imported", 18 ])
      expect([ second.rows[76].outcome, second.rows[76].product_id ]).to eq([ "already_imported", 18 ])
      expect(second.rows[53].review_case_id).to eq(first.rows[53].review_case_id)
      expect(second.rows[87].review_case_id).to eq(first.rows[87].review_case_id)
      expect(second.rows[180].outcome).to eq("failed")
      expect(second.totals.fetch("created")).to eq(0)
      expect(second.totals.fetch("linked")).to eq(0)
      expect(Intake::Models::SellerItem.count).to eq(item_count)
      expect(Intake::Models::ReviewCase.count).to eq(case_count)
      expect(Catalog::Models::SellerProduct.count).to eq(association_count)
      expect_reconciled(first)
      expect_reconciled(second)
    end
  end
end
