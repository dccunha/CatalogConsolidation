require "rails_helper"

RSpec.describe Catalog::Models::Product, type: :model do
  describe ".table_name" do
    it "maps to the catalog products table" do
      expect(described_class.table_name).to eq("products")
    end
  end

  describe "persistence" do
    it "keeps an explicit reference ID and nullable catalog attributes" do
      product = described_class.create!(id: 975, name: "Reference product", brand: nil, category: nil)

      expect(product.reload.attributes.slice("id", "name", "brand", "category")).to eq(
        "id" => 975, "name" => "Reference product", "brand" => nil, "category" => nil
      )
    end

    it "allows separate products with identical names" do
      first = FactoryBot.create(:catalog_product, name: "Shared name")
      second = FactoryBot.create(:catalog_product, name: "Shared name")

      expect(second.id).not_to eq(first.id)
      expect(described_class.where(name: "Shared name").count).to eq(2)
    end

    it "rejects blank names through the database check" do
      expect do
        described_class.insert_all!([ { name: " \t\n" } ])
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
