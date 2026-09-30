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

    it "stores SQL-like seller strings as data without executing them" do
      quoted = row.merge("Id" => "001'; DROP TABLE products; --",
        "SellerName" => "O'Reilly; DELETE FROM intake_batches; --",
        "Name" => "Widget'); DROP TABLE products; --")

      result = import(quoted)

      expect(result.rows.first.outcome).to eq("created")
      expect(Catalog::Models::Product.find(result.rows.first.product_id).name).to eq(quoted["Name"])
      expect(Catalog::Models::SellerProduct.find_by!(seller_name: quoted["SellerName"],
        seller_product_id: quoted["Id"]).product_id).to eq(result.rows.first.product_id)
      expect(Intake::Models::Batch.find(result.batch_id).input_count).to eq(1)
      expect_reconciled(result)
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
end
