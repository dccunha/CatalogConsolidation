require "rails_helper"

RSpec.describe Catalog::Public::Writes, type: :model do
  describe ".link" do
    let(:product) { FactoryBot.create(:catalog_product, name: "Original", brand: "Brand", category: "Category") }

    it "links an existing product while preserving its attributes and the exact seller key" do
      attributes = product.attributes.slice("name", "brand", "category")
      seller_name = "  O'Reilly; DROP TABLE products; --  "
      seller_product_id = "000'1); DELETE FROM seller_products; --"

      association = described_class.link(product_id: product.id, seller_name: seller_name,
        seller_product_id: seller_product_id)

      expect(association.reload.attributes.slice("seller_name", "seller_product_id", "product_id")).to eq(
        "seller_name" => seller_name, "seller_product_id" => seller_product_id, "product_id" => product.id
      )
      expect(product.reload.attributes.slice("name", "brand", "category")).to eq(attributes)
      expect(Catalog::Models::Product.exists?(product.id)).to be(true)
    end

    it "reports the existing association when a seller item is already linked" do
      existing = FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop",
        seller_product_id: "item")
      other = FactoryBot.create(:catalog_product)

      expect do
        described_class.link(product_id: other.id, seller_name: "Shop", seller_product_id: "item")
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:seller_item_taken)
        expect(error.existing_association_id).to eq(existing.id)
      }
      expect(existing.reload.product_id).to eq(product.id)
    end

    it "reports the seller's existing item when the product is already offered" do
      existing = FactoryBot.create(:catalog_seller_product, product: product, seller_name: "Shop",
        seller_product_id: "first")

      expect do
        described_class.link(product_id: product.id, seller_name: "Shop", seller_product_id: "second")
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:seller_product_taken)
        expect(error.existing_association_id).to eq(existing.id)
        expect(error.message).to include("first")
      }
      expect(Catalog::Models::SellerProduct.where(seller_name: "Shop").count).to eq(1)
    end

    it "does not create an association for a missing product" do
      expect do
        described_class.link(product_id: -1, seller_name: "Shop", seller_product_id: "item")
      end.to raise_error(ActiveRecord::RecordNotFound)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
    end

    it "reports a uniqueness failure that occurs after the conflict check" do
      allow(Catalog::Models::SellerProduct).to receive(:create!).and_raise(
        ActiveRecord::RecordNotUnique.new("index_seller_products_on_seller_identity")
      )

      expect do
        described_class.link(product_id: product.id, seller_name: "Shop", seller_product_id: "racing-item")
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:database_unique_conflict)
        expect(error.message).to include("index_seller_products_on_seller_identity")
      }
    end
  end

  describe ".create_with_association" do
    it "creates one product and association with exact supplied values" do
      name = "Câmera 'x'; DROP TABLE products; --"
      association = described_class.create_with_association(name: name, brand: " Bränd ", category: "Photo; --",
        seller_name: "Shop'", seller_product_id: "0001' OR '1'='1")

      expect(association.reload.attributes.slice("seller_name", "seller_product_id")).to eq(
        "seller_name" => "Shop'", "seller_product_id" => "0001' OR '1'='1"
      )
      expect(association.product.reload.attributes.slice("name", "brand", "category")).to eq(
        "name" => name, "brand" => " Bränd ", "category" => "Photo; --"
      )
      expect(Catalog::Models::Product.count).to eq(1)
    end

    it "rolls back the product when the association fails validation" do
      expect do
        described_class.create_with_association(name: "New", brand: nil, category: nil,
          seller_name: " ", seller_product_id: "item")
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(Catalog::Models::Product.count).to eq(0)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
    end

    it "rolls back the product when the seller key conflicts" do
      existing = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "item")
      count = Catalog::Models::Product.count

      expect do
        described_class.create_with_association(name: "New", brand: "B", category: "C",
          seller_name: "Shop", seller_product_id: "item")
      end.to raise_error(described_class::ConflictError, /association #{existing.id}/)
      expect(Catalog::Models::Product.count).to eq(count)
      expect(existing.reload.product.name).not_to eq("New")
    end

    it "rejects a blank product name without an association" do
      expect do
        described_class.create_with_association(name: " ", brand: "B", category: "C",
          seller_name: "Shop", seller_product_id: "item")
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(Catalog::Models::SellerProduct.count).to eq(0)
    end
  end

  describe ".reassign" do
    it "changes the existing association's product and item ID without changing either product" do
      original = FactoryBot.create(:catalog_product, name: "Original", brand: "Old", category: "First")
      target = FactoryBot.create(:catalog_product, name: "Target", brand: "New", category: "Second")
      original_fields = original.attributes.slice("name", "brand", "category")
      target_fields = target.attributes.slice("name", "brand", "category")
      association = FactoryBot.create(:catalog_seller_product, product: original, seller_name: "Shop", seller_product_id: "old")

      result = described_class.reassign(association_id: association.id, product_id: target.id,
        seller_product_id: "new' --")

      expect(result.id).to eq(association.id)
      expect(result.reload.attributes.slice("seller_name", "seller_product_id", "product_id")).to eq(
        "seller_name" => "Shop", "seller_product_id" => "new' --", "product_id" => target.id
      )
      expect(original.reload.attributes.slice("name", "brand", "category")).to eq(original_fields)
      expect(target.reload.attributes.slice("name", "brand", "category")).to eq(target_fields)
    end

    it "replaces a conflicting seller ID in place for an explicit review decision" do
      association = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "displaced")

      described_class.reassign(association_id: association.id, product_id: association.product_id,
        seller_product_id: "survivor")

      expect(Catalog::Models::SellerProduct.where(seller_name: "Shop").pluck(:seller_product_id)).to eq([ "survivor" ])
    end

    it "leaves the association untouched when another item already offers the target product" do
      original = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "first")
      target = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "second")

      expect do
        described_class.reassign(association_id: original.id, product_id: target.product_id,
          seller_product_id: "first")
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:seller_product_taken)
        expect(error.existing_association_id).to eq(target.id)
      }
      expect(original.reload.product_id).not_to eq(target.product_id)
    end

    it "leaves the association untouched when the new seller ID is already linked" do
      original = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "first")
      other = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "second")

      expect do
        described_class.reassign(association_id: original.id, product_id: original.product_id,
          seller_product_id: other.seller_product_id)
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:seller_item_taken)
        expect(error.existing_association_id).to eq(other.id)
      }
      expect(original.reload.seller_product_id).to eq("first")
    end

    it "leaves the association untouched for a missing target product" do
      association = FactoryBot.create(:catalog_seller_product)

      expect do
        described_class.reassign(association_id: association.id, product_id: -1, seller_product_id: "new")
      end.to raise_error(ActiveRecord::RecordNotFound)
      expect(association.reload.seller_product_id).not_to eq("new")
    end
  end

  describe "transaction composition" do
    it "rolls back Catalog creation with an enclosing Intake transaction" do
      Catalog::Models::Product.transaction do
        described_class.create_with_association(name: "Pending", brand: "B", category: "C",
          seller_name: "Shop", seller_product_id: "item")
        raise ActiveRecord::Rollback
      end

      expect(Catalog::Models::Product.where(name: "Pending")).to be_empty
      expect(Catalog::Models::SellerProduct.where(seller_name: "Shop")).to be_empty
    end

    it "rolls back a link and reassignment with an enclosing Intake transaction" do
      original = FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "old")
      original_product_id = original.product_id
      target = FactoryBot.create(:catalog_product)

      Catalog::Models::Product.transaction do
        described_class.link(product_id: target.id, seller_name: "Other", seller_product_id: "item")
        described_class.reassign(association_id: original.id, product_id: target.id, seller_product_id: "new")
        raise ActiveRecord::Rollback
      end

      expect(original.reload.attributes.slice("seller_product_id", "product_id")).to eq(
        "seller_product_id" => "old", "product_id" => original_product_id
      )
      expect(Catalog::Models::SellerProduct.where(seller_name: "Other")).to be_empty
    end

    it "allows an outer transaction to continue after a failed Catalog savepoint" do
      Catalog::Models::Product.transaction do
        begin
          described_class.create_with_association(name: "Rolled back", brand: "B", category: "C",
            seller_name: " ", seller_product_id: "bad")
        rescue ActiveRecord::RecordInvalid
          # Intake records a failed row and continues within its transaction.
        end
        described_class.create_with_association(name: "Committed", brand: "B", category: "C",
          seller_name: "Shop", seller_product_id: "good")
      end

      expect(Catalog::Models::Product.pluck(:name)).to eq([ "Committed" ])
      expect(Catalog::Models::SellerProduct.pluck(:seller_product_id)).to eq([ "good" ])
    end
  end
end
