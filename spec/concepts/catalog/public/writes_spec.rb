require "rails_helper"

RSpec.describe Catalog::Public::Writes, type: :model do
  describe ".link" do
    let(:product) { FactoryBot.create(:catalog_product, name: "Original", brand: "Brand", category: "Category") }

    it "links an existing product while preserving its attributes and the exact seller key" do
      attributes = product.attributes.slice("name", "brand", "category")
      seller_name = "  O'Reilly; DROP TABLE products; --  "
      seller_product_id = "000'1); DELETE FROM seller_products; --"
      product_count = Catalog::Models::Product.count
      association_count = Catalog::Models::SellerProduct.count

      association = described_class.link(product_id: product.id, seller_name: seller_name,
        seller_product_id: seller_product_id)

      expect(association.reload.attributes.slice("seller_name", "seller_product_id", "product_id")).to eq(
        "seller_name" => seller_name, "seller_product_id" => seller_product_id, "product_id" => product.id
      )
      expect(product.reload.attributes.slice("name", "brand", "category")).to eq(attributes)
      expect(Catalog::Models::Product.exists?(product.id)).to be(true)
      expect(Catalog::Models::Product.count).to eq(product_count)
      expect(Catalog::Models::SellerProduct.count).to eq(association_count + 1)
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
      product_count = Catalog::Models::Product.count
      association_count = Catalog::Models::SellerProduct.count
      association = described_class.create_with_association(name: name, brand: " Bränd ", category: "Photo; --",
        seller_name: "Shop'", seller_product_id: "0001' OR '1'='1")

      expect(association.reload.attributes.slice("seller_name", "seller_product_id")).to eq(
        "seller_name" => "Shop'", "seller_product_id" => "0001' OR '1'='1"
      )
      expect(association.product.reload.attributes.slice("name", "brand", "category")).to eq(
        "name" => name, "brand" => " Bränd ", "category" => "Photo; --"
      )
      expect(Catalog::Models::Product.count).to eq(product_count + 1)
      expect(Catalog::Models::SellerProduct.count).to eq(association_count + 1)
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
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:seller_item_taken)
        expect(error.existing_association_id).to eq(existing.id)
      }
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
      product_count = Catalog::Models::Product.count
      association_count = Catalog::Models::SellerProduct.count

      result = described_class.reassign(association_id: association.id, product_id: target.id,
        seller_product_id: "new' --")

      expect(result.id).to eq(association.id)
      expect(result.reload.attributes.slice("seller_name", "seller_product_id", "product_id")).to eq(
        "seller_name" => "Shop", "seller_product_id" => "new' --", "product_id" => target.id
      )
      expect(original.reload.attributes.slice("name", "brand", "category")).to eq(original_fields)
      expect(target.reload.attributes.slice("name", "brand", "category")).to eq(target_fields)
      expect(Catalog::Models::Product.count).to eq(product_count)
      expect(Catalog::Models::SellerProduct.count).to eq(association_count)
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

  describe ".create_for_association" do
    let(:association) do
      FactoryBot.create(:catalog_seller_product, seller_name: " Shop' -- ", seller_product_id: "000'1",
        product: FactoryBot.create(:catalog_product, name: "Old product"))
    end

    it "creates one product and moves the existing association without changing its seller key" do
      old_product = association.product
      old_fields = old_product.attributes.slice("name", "brand", "category")
      product_count = Catalog::Models::Product.count
      association_count = Catalog::Models::SellerProduct.count

      result = described_class.create_for_association(association_id: association.id,
        expected_product_id: old_product.id, expected_seller_product_id: "000'1",
        name: "New 'product'; --", brand: "Bränd", category: "New category")

      expect(result.id).to eq(association.id)
      expect(result.reload.attributes.slice("seller_name", "seller_product_id")).to eq(
        "seller_name" => " Shop' -- ", "seller_product_id" => "000'1"
      )
      expect(result.product.attributes.slice("name", "brand", "category")).to eq(
        "name" => "New 'product'; --", "brand" => "Bränd", "category" => "New category"
      )
      expect(old_product.reload.attributes.slice("name", "brand", "category")).to eq(old_fields)
      expect(Catalog::Models::Product.count).to eq(product_count + 1)
      expect(Catalog::Models::SellerProduct.count).to eq(association_count)
    end

    it "rejects an association moved since review without creating a product" do
      old_product_id = association.product_id
      current = FactoryBot.create(:catalog_product)
      association.update!(product: current)
      count = Catalog::Models::Product.count

      expect do
        described_class.create_for_association(association_id: association.id,
          expected_product_id: old_product_id, expected_seller_product_id: association.seller_product_id,
          name: "New", brand: "B", category: "C")
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:stale_association)
        expect(error.existing_association_id).to eq(association.id)
      }
      expect(Catalog::Models::Product.count).to eq(count)
      expect(association.reload.product_id).to eq(current.id)
    end

    it "rejects a changed seller item ID since review" do
      association.update!(seller_product_id: "newer")

      expect do
        described_class.create_for_association(association_id: association.id,
          expected_product_id: association.product_id, expected_seller_product_id: "000'1",
          name: "New", brand: "B", category: "C")
      end.to raise_error(described_class::ConflictError, /changed since review/)
      expect(Catalog::Models::Product.where(name: "New")).to be_empty
    end

    it "does not move the association for an invalid new product" do
      old_product_id = association.product_id

      expect do
        described_class.create_for_association(association_id: association.id,
          expected_product_id: old_product_id, expected_seller_product_id: association.seller_product_id,
          name: " ", brand: "B", category: "C")
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(association.reload.product_id).to eq(old_product_id)
    end

    it "rolls back a new product when the association move fails at the database" do
      old_product_id = association.product_id
      seller_key = association.attributes.slice("seller_name", "seller_product_id")
      product_count = Catalog::Models::Product.count
      connection = Catalog::Models::SellerProduct.connection
      constraint_name = "t03_reject_association_move"
      connection.add_check_constraint(:seller_products, "product_id = #{old_product_id}", name: constraint_name)

      begin
        expect do
          described_class.create_for_association(association_id: association.id,
            expected_product_id: old_product_id, expected_seller_product_id: association.seller_product_id,
            name: "Created before failed move", brand: "B", category: "C")
        end.to raise_error(ActiveRecord::StatementInvalid, /t03_reject_association_move/)

        expect(Catalog::Models::Product.count).to eq(product_count)
        expect(association.reload.attributes.slice("seller_name", "seller_product_id", "product_id")).to eq(
          seller_key.merge("product_id" => old_product_id)
        )
      ensure
        connection.remove_check_constraint(:seller_products, name: constraint_name)
      end
    end

    it "rolls the new product and association move back with the enclosing transaction" do
      old_product_id = association.product_id

      Catalog::Models::Product.transaction do
        described_class.create_for_association(association_id: association.id,
          expected_product_id: old_product_id, expected_seller_product_id: association.seller_product_id,
          name: "Pending", brand: "B", category: "C")
        raise ActiveRecord::Rollback
      end

      expect(Catalog::Models::Product.where(name: "Pending")).to be_empty
      expect(association.reload.product_id).to eq(old_product_id)
    end
  end

  describe ".replace_listing" do
    let(:survivor) do
      FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "incoming",
        product: FactoryBot.create(:catalog_product, name: "Old"))
    end
    let(:displaced) do
      FactoryBot.create(:catalog_seller_product, seller_name: "Shop", seller_product_id: "displaced",
        product: FactoryBot.create(:catalog_product, name: "Target"))
    end

    def replace_listing(survivor:, displaced:, **overrides)
      described_class.replace_listing(**{
        survivor_association_id: survivor.id, displaced_association_id: displaced.id,
        expected_survivor_product_id: survivor.product_id, expected_displaced_product_id: displaced.product_id,
        expected_survivor_seller_product_id: survivor.seller_product_id,
        expected_displaced_seller_product_id: displaced.seller_product_id
      }.merge(overrides))
    end

    it "keeps the chosen association, displaces the other, and leaves both products unchanged" do
      old_product = survivor.product
      target_product = displaced.product
      old_fields = old_product.attributes.slice("name", "brand", "category")
      target_fields = target_product.attributes.slice("name", "brand", "category")
      product_count = Catalog::Models::Product.count
      association_count = Catalog::Models::SellerProduct.count

      result = replace_listing(survivor: survivor, displaced: displaced)

      expect(result.id).to eq(survivor.id)
      expect(result.reload.attributes.slice("seller_name", "seller_product_id", "product_id")).to eq(
        "seller_name" => "Shop", "seller_product_id" => "incoming", "product_id" => target_product.id
      )
      expect(Catalog::Models::SellerProduct.exists?(displaced.id)).to be(false)
      expect(old_product.reload.attributes.slice("name", "brand", "category")).to eq(old_fields)
      expect(target_product.reload.attributes.slice("name", "brand", "category")).to eq(target_fields)
      expect(Catalog::Models::Product.count).to eq(product_count)
      expect(Catalog::Models::SellerProduct.count).to eq(association_count - 1)
      expect(Catalog::Models::SellerProduct.where(seller_name: "Shop", product_id: target_product.id).count).to eq(1)
    end

    it "rejects a stale survivor product without displacing the other association" do
      old_product_id = survivor.product_id
      survivor.update!(product: FactoryBot.create(:catalog_product))

      expect do
        replace_listing(survivor: survivor, displaced: displaced,
          expected_survivor_product_id: old_product_id)
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:stale_association)
        expect(error.existing_association_id).to eq(survivor.id)
      }
      expect(Catalog::Models::SellerProduct.exists?(displaced.id)).to be(true)
    end

    it "rejects a stale displaced seller item ID" do
      displaced.update!(seller_product_id: "newer")

      expect do
        replace_listing(survivor: survivor, displaced: displaced,
          expected_displaced_seller_product_id: "displaced")
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:stale_association)
        expect(error.existing_association_id).to eq(displaced.id)
      }
      expect(Catalog::Models::SellerProduct.exists?(displaced.id)).to be(true)
    end

    it "rejects associations from different sellers" do
      displaced.update!(seller_name: "Other")

      expect do
        replace_listing(survivor: survivor, displaced: displaced)
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:seller_mismatch)
      }
      expect(Catalog::Models::SellerProduct.exists?(displaced.id)).to be(true)
    end

    it "requires two distinct association IDs" do
      expect do
        replace_listing(survivor: survivor, displaced: survivor)
      end.to raise_error(ArgumentError, /must differ/)
      expect(Catalog::Models::SellerProduct.exists?(survivor.id)).to be(true)
    end

    it "restores the displaced association if a uniqueness race interrupts the move" do
      old_product_id = survivor.product_id
      target_product_id = displaced.product_id
      allow(described_class).to receive(:check_conflicts).and_raise(
        ActiveRecord::RecordNotUnique.new("index_seller_products_on_seller_and_product")
      )

      expect do
        replace_listing(survivor: survivor, displaced: displaced)
      end.to raise_error(described_class::ConflictError) { |error|
        expect(error.kind).to eq(:database_unique_conflict)
      }
      expect(survivor.reload.product_id).to eq(old_product_id)
      expect(displaced.reload.product_id).to eq(target_product_id)
      expect(Catalog::Models::SellerProduct.where(seller_name: "Shop").count).to eq(2)
    end

    it "rolls the displacement and move back with the enclosing transaction" do
      old_product_id = survivor.product_id
      target_product_id = displaced.product_id

      Catalog::Models::Product.transaction do
        replace_listing(survivor: survivor, displaced: displaced)
        raise ActiveRecord::Rollback
      end

      expect(survivor.reload.product_id).to eq(old_product_id)
      expect(displaced.reload.product_id).to eq(target_product_id)
      expect(Catalog::Models::SellerProduct.where(seller_name: "Shop").count).to eq(2)
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
