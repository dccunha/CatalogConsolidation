require "rails_helper"

RSpec.describe Intake::Services::RowValidator, type: :model do
  let(:row) do
    { "Id" => "001-not-a-uuid", "SellerName" => "MegaStore", "Name" => "Smartphone Galaxy S23",
      "Brand" => "Samsung", "Category" => "Electronics" }
  end

  describe ".call" do
    it "preserves exact seller keys and source values" do
      input = row.merge("Id" => "  000-X'  ", "SellerName" => "  MegaStore  ",
        "Name" => "  Câmera  ", "Brand" => " SÁMSUNG ")
      result = described_class.call(input)

      expect([ result.source.seller_product_id, result.source.seller_name, result.source.name,
        result.source.brand, result.comparison.name ]).to eq(
          [ "  000-X'  ", "  MegaStore  ", "  Câmera  ", " SÁMSUNG ", "camera" ]
        )
    end

    it "keeps case-distinct sellers as distinct exact keys" do
      first = described_class.call(row)
      second = described_class.call(row.merge("SellerName" => "megastore"))

      expect(first.source.seller_name).not_to eq(second.source.seller_name)
    end

    it "marks missing brand for review without changing the source" do
      result = described_class.call(row.merge("Name" => "Cable Organizer Kit", "Brand" => nil))

      expect([ result.source.brand, result.comparison.brand, result.review_required? ]).to eq([ nil, nil, true ])
    end

    it "marks blank category for review while preserving its whitespace" do
      result = described_class.call(row.merge("Category" => " \t "))

      expect([ result.source.category, result.comparison.category, result.review_required? ]).to eq(
        [ " \t ", nil, true ]
      )
    end

    it "marks both omitted metadata fields for review" do
      result = described_class.call(row.except("Brand", "Category"))

      expect([ result.source.brand, result.source.category, result.review_required? ]).to eq([ nil, nil, true ])
    end

    it "does not request metadata review for complete rows" do
      expect(described_class.call(row).review_required?).to be(false)
    end

    it "returns a field error for null and blank required values" do
      result = described_class.call(row.merge("Id" => nil, "SellerName" => " \u00a0 ", "Name" => ""))

      expect(result.errors.map { |error| [ error.field, error.code ] }).to eq([
        [ "Id", :required ], [ "SellerName", :required ], [ "Name", :required ]
      ])
    end

    it "returns a required error for omitted required fields" do
      result = described_class.call(row.except("Id"))

      expect(result.errors.map(&:code)).to eq([ :required ])
    end

    it "returns type errors for malformed values instead of coercing them" do
      result = described_class.call(row.merge("Id" => 123, "SellerName" => [ "Shop" ],
        "Name" => { "text" => "Phone" }, "Brand" => false, "Category" => 7))

      expect(result.errors.map { |error| [ error.field, error.code ] }).to eq([
        [ "Id", :invalid_type ], [ "SellerName", :invalid_type ], [ "Name", :invalid_type ],
        [ "Brand", :invalid_type ], [ "Category", :invalid_type ]
      ])
    end

    it "returns a row error for a non-object array element" do
      result = described_class.call([ "not a product" ])

      expect([ result.input, result.errors.map { |error| [ error.field, error.code ] } ]).to eq(
        [ [ "not a product" ], [ [ nil, :not_an_object ] ] ]
      )
    end

    it "allows a later row to validate after an invalid element" do
      results = [ nil, row ].map { |element| described_class.call(element) }

      expect(results.map(&:class)).to eq([ described_class::Invalid, described_class::Valid ])
    end
  end
end
