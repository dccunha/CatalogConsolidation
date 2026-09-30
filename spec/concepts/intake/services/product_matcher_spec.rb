require "rails_helper"

RSpec.describe Intake::Services::ProductMatcher, type: :model do
  let(:row) do
    { "Id" => "001", "SellerName" => "MegaStore", "Name" => "Smartphone Galaxy S23",
      "Brand" => "Samsung", "Category" => "Electronics" }
  end

  def match(overrides = {})
    valid = Intake::Services::RowValidator.call(row.merge(overrides))
    described_class.call(valid: valid)
  end

  describe ".call" do
    it "matches Galaxy to product 2 in the supplied reference catalog" do
      Catalog::Services::ReferenceCatalogLoader.call

      result = match

      expect([ result.recommendation, result.product_id ]).to eq([ :link, 2 ])
    end

    it "recommends the sole complete normalized Galaxy match by its existing product ID" do
      product = FactoryBot.create(:catalog_product, name: "  Smártphone   GALAXY S23 ",
        brand: "SAMSUNG", category: "electronics")

      result = match

      expect([ result.recommendation, result.product_id, result.reasons ]).to eq([ :link, product.id, [] ])
      expect(result.candidates.map(&:product_id)).to eq([ product.id ])
      expect(result.candidates.first.differing_fields).to eq([])
      expect(result.candidates.first.original.name).to eq("  Smártphone   GALAXY S23 ")
      expect(result.candidates.first.comparison.name).to eq("smartphone galaxy s23")
    end

    it "requires review when two products share the complete normalized identity" do
      products = [ FactoryBot.create(:catalog_product, name: row["Name"]),
        FactoryBot.create(:catalog_product, name: "SMARTPHONE GALAXY S23") ]
      products.each { |product| product.update!(brand: row["Brand"], category: row["Category"]) }

      result = match

      expect([ result.recommendation, result.product_id, result.reasons ]).to eq(
        [ :review, nil, [ :multiple_exact_matches ] ]
      )
      expect(result.candidates.map(&:product_id)).to eq(products.map(&:id))
    end

    it "requires review when one exact product has another identical-name candidate with conflicting metadata" do
      exact = FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      conflict = FactoryBot.create(:catalog_product, name: "SMARTPHONE GALAXY S23", brand: "Other", category: "Other")

      result = match

      expect([ result.recommendation, result.product_id, result.reasons ]).to eq(
        [ :review, nil, [ :additional_candidates ] ]
      )
      expect(result.candidates.map(&:product_id)).to eq([ exact.id, conflict.id ])
      expect(result.candidates.map(&:differing_fields)).to eq([ [], [ :brand, :category ] ])
    end

    it "requires review when one exact product has another credible near-name candidate" do
      exact = FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      near = FactoryBot.create(:catalog_product, name: "Smartphone Galaxy S24", brand: row["Brand"],
        category: row["Category"])

      result = match

      expect([ result.recommendation, result.product_id, result.reasons ]).to eq(
        [ :review, nil, [ :additional_candidates ] ]
      )
      expect(result.candidates.map(&:product_id)).to eq([ exact.id, near.id ])
      expect(result.candidates.last.differing_fields).to eq([ :name ])
    end

    it "shows reference iPad punctuation and category evidence without linking or creating" do
      Catalog::Services::ReferenceCatalogLoader.call

      result = match("Name" => "Tablet iPad Pro 12.9''", "Brand" => "Apple", "Category" => "Tablets")
      candidate = result.candidates.find { |item| item.product_id == 14 }

      expect([ result.recommendation, result.reasons ]).to eq([ :review, [ :candidate_review ] ])
      expect([ candidate.original.name, candidate.original.brand, candidate.original.category ]).to eq(
        [ 'Tablet iPad Pro 12.9"', "Apple", "Tablets" ]
      )
      expect([ candidate.comparison.name, candidate.comparison.brand, candidate.comparison.category ]).to eq(
        [ 'tablet ipad pro 12.9"', "apple", "tablets" ]
      )
      expect(candidate.differing_fields).to eq([ :name ])
      expect(candidate.score).to be >= 0.80
    end

    it "shows the Canon category conflict on an identical name" do
      product = FactoryBot.create(:catalog_product, name: "Camera Canon EOS R6",
        brand: "Canon", category: "Photography")

      result = match("Name" => "Camera Canon EOS R6", "Brand" => "Canon", "Category" => "Photo")

      expect([ result.recommendation, result.reasons, result.candidates.map(&:product_id) ]).to eq(
        [ :review, [ :candidate_review ], [ product.id ] ]
      )
      expect(result.candidates.first.differing_fields).to eq([ :category ])
      expect(result.candidates.first.original.category).to eq("Photography")
      expect(result.candidates.first.comparison.category).to eq("photography")
    end

    it "includes an identical name despite a different brand and category" do
      product = FactoryBot.create(:catalog_product, name: row["Name"], brand: "Other", category: "Other")

      result = match

      expect(result.candidates.map(&:product_id)).to eq([ product.id ])
      expect(result.candidates.first.differing_fields).to eq([ :brand, :category ])
      expect(result.recommendation).to eq(:review)
    end

    it "requires review when metadata is absent even with an exact matching name" do
      product = FactoryBot.create(:catalog_product, name: "Cable Organizer Kit", brand: nil, category: "Home")

      result = match("Name" => "Cable Organizer Kit", "Brand" => nil, "Category" => "Home")

      expect([ result.recommendation, result.product_id, result.reasons ]).to eq(
        [ :review, nil, [ :incomplete_metadata ] ]
      )
      expect(result.candidates.map(&:product_id)).to eq([ product.id ])
    end

    it "requires review for incomplete metadata with no candidates" do
      result = match("Brand" => "  ")

      expect([ result.recommendation, result.product_id, result.reasons, result.candidates ]).to eq(
        [ :review, nil, [ :incomplete_metadata ], [] ]
      )
    end

    it "finds the reference router at about 0.826 with Networking category evidence" do
      Catalog::Services::ReferenceCatalogLoader.call

      result = match("Name" => "Roteador WiFi 6 TP-Link", "Brand" => "TP-Link", "Category" => "Networking")
      candidate = result.candidates.find { |item| item.product_id == 21 }

      expect([ candidate.original.name, candidate.original.brand, candidate.original.category ]).to eq(
        [ "Router WiFi 6 TP-Link", "TP-Link", "Networking" ]
      )
      expect([ candidate.comparison.name, candidate.comparison.brand, candidate.comparison.category ]).to eq(
        [ "router wifi 6 tp-link", "tp-link", "networking" ]
      )
      expect(candidate.score).to be_within(0.001).of(0.826)
      expect(candidate.differing_fields).to eq([ :name ])
      expect(result.recommendation).to eq(:review)
    end

    it "includes a name at the 0.80 boundary when brand matches" do
      product = FactoryBot.create(:catalog_product, name: "abcde", brand: "Brand")

      result = match("Name" => "abcdx", "Brand" => "Brand", "Category" => "Example category")

      expect(result.candidates.map(&:product_id)).to eq([ product.id ])
      expect(result.candidates.first.score).to eq(0.8)
    end

    it "measures the name threshold over Unicode characters" do
      product = FactoryBot.create(:catalog_product, name: "абвгд", brand: "Brand")

      result = match("Name" => "абвгх", "Brand" => "Brand", "Category" => "Example category")

      expect(result.candidates.map(&:product_id)).to eq([ product.id ])
      expect(result.candidates.first.score).to eq(0.8)
    end

    it "excludes names below 0.80 or with a nonmatching brand" do
      FactoryBot.create(:catalog_product, name: "abcde", brand: "Brand")
      FactoryBot.create(:catalog_product, name: "abcdx", brand: "Other")

      result = match("Name" => "abcxy", "Brand" => "Brand", "Category" => "Example category")

      expect(result.candidates).to eq([])
      expect(result.recommendation).to eq(:create)
    end

    it "ranks score, brand, category, then product ID" do
      category_mismatch = FactoryBot.create(:catalog_product, name: "alpha", brand: "Brand", category: "Other")
      brand_mismatch = FactoryBot.create(:catalog_product, name: "alpha", brand: "Other", category: "Category")
      tie_low = FactoryBot.create(:catalog_product, name: "alpha", brand: "Brand", category: "Category")
      tie_high = FactoryBot.create(:catalog_product, name: "alpha", brand: "Brand", category: "Category")
      near = FactoryBot.create(:catalog_product, name: "alphx", brand: "Brand", category: "Category")

      result = match("Name" => "alpha", "Brand" => "Brand", "Category" => "Category")

      expect(result.candidates.map(&:product_id)).to eq(
        [ tie_low.id, tie_high.id, category_mismatch.id, brand_mismatch.id, near.id ]
      )
      expect(result.recommendation).to eq(:review)
    end

    it "keeps capacity and color variants separate from automatic links" do
      capacity = FactoryBot.create(:catalog_product, name: "Phone 128GB Black", brand: "Brand", category: "Phones")
      color = FactoryBot.create(:catalog_product, name: "Phone 256GB Blue", brand: "Brand", category: "Phones")

      result = match("Name" => "Phone 256GB Black", "Brand" => "Brand", "Category" => "Phones")

      expect(result.candidates.map(&:product_id)).to contain_exactly(capacity.id, color.id)
      expect(result.candidates.map(&:differing_fields)).to eq([ [ :name ], [ :name ] ])
      expect(result.recommendation).to eq(:review)
    end

    it "shows the exact seller item association and blocks a new recommendation" do
      existing = FactoryBot.create(:catalog_seller_product, seller_name: "MegaStore", seller_product_id: "001")

      result = match("Name" => "Completely New", "Brand" => "New", "Category" => "New")

      expect([ result.recommendation, result.reasons, result.seller_item_association.id,
        result.seller_item_association.product_id ]).to eq(
          [ :review, [ :seller_item_taken ], existing.id, existing.product_id ]
        )
    end

    it "shows a seller product conflict for a different exact seller item ID" do
      product = FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      existing = FactoryBot.create(:catalog_seller_product, product: product,
        seller_name: "MegaStore", seller_product_id: "other")

      result = match

      expect([ result.recommendation, result.reasons, result.candidates.first.seller_product_conflict.id,
        result.candidates.first.seller_product_conflict.seller_product_id ]).to eq(
          [ :review, [ :seller_product_taken ], existing.id, "other" ]
        )
    end

    it "does not confuse case-distinct sellers or other sellers with a conflict" do
      product = FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "megastore", seller_product_id: "001")
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Another", seller_product_id: "001")

      result = match

      expect([ result.recommendation, result.product_id, result.seller_item_association,
        result.candidates.first.seller_product_conflict ]).to eq([ :link, product.id, nil, nil ])
    end

    it "leaves Catalog records and their attributes unchanged after gathering evidence" do
      product = FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "MegaStore", seller_product_id: "other")
      before = [ Catalog::Models::Product.order(:id).map(&:attributes),
        Catalog::Models::SellerProduct.order(:id).map(&:attributes) ]

      match

      expect([ Catalog::Models::Product.order(:id).map(&:attributes),
        Catalog::Models::SellerProduct.order(:id).map(&:attributes) ]).to eq(before)
    end

    it "requeries current Catalog records on each call" do
      first = match
      product = FactoryBot.create(:catalog_product, name: row["Name"], brand: row["Brand"], category: row["Category"])
      second = match
      product.update!(category: "Other")
      third = match

      expect([ first.recommendation, second.recommendation, second.product_id,
        third.recommendation, third.candidates.first.differing_fields ]).to eq(
          [ :create, :link, product.id, :review, [ :category ] ]
        )
    end
  end
end
