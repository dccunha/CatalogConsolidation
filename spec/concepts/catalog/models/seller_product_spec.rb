require "rails_helper"

RSpec.describe Catalog::Models::SellerProduct, type: :model do
  describe ".table_name" do
    it "maps to the seller associations table" do
      expect(described_class.table_name).to eq("seller_products")
    end
  end

  describe "persistence" do
    let(:product) { FactoryBot.create(:catalog_product) }

    it "preserves opaque text IDs and seller names exactly" do
      association = FactoryBot.create(:catalog_seller_product, product: product,
        seller_name: "  Câmera Shop  ", seller_product_id: "0001/abc-XYZ")

      expect(association.reload.attributes.slice("seller_name", "seller_product_id")).to eq(
        "seller_name" => "  Câmera Shop  ", "seller_product_id" => "0001/abc-XYZ"
      )
    end

    it "rejects another product for the same seller item at the database level" do
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop", seller_product_id: "0001")

      expect do
        described_class.insert_all!([ { seller_name: "Shop", seller_product_id: "0001",
          product_id: FactoryBot.create(:catalog_product).id } ])
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "reports a reused seller item before attempting to persist it" do
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop", seller_product_id: "0001")
      duplicate = FactoryBot.build(:catalog_seller_product, seller_name: "Shop", seller_product_id: "0001")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:seller_product_id]).to include("has already been taken")
    end

    it "rejects another item for the same seller and product at the database level" do
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop", seller_product_id: "first")

      expect do
        described_class.insert_all!([ { seller_name: "Shop", seller_product_id: "second", product_id: product.id } ])
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "reports a second item for the same seller and product before persistence" do
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop", seller_product_id: "first")
      duplicate = FactoryBot.build(:catalog_seller_product, product: product,
        seller_name: "Shop", seller_product_id: "second")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_id]).to include("has already been taken")
    end

    it "allows independent sellers to offer the same product" do
      FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop A")
      other = FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop B")

      expect(other.reload.product).to eq(product)
    end

    it "rejects an association with a nonexistent product" do
      expect do
        described_class.insert_all!([ { seller_name: "Shop", seller_product_id: "missing", product_id: -1 } ])
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects blank seller identities through database checks" do
      expect do
        described_class.insert_all!([ { seller_name: " \t", seller_product_id: "item", product_id: product.id } ])
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects blank seller item IDs through database checks" do
      expect do
        described_class.insert_all!([ { seller_name: "Shop", seller_product_id: " \n", product_id: product.id } ])
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
