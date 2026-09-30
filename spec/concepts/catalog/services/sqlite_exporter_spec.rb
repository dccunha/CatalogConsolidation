require "rails_helper"
require "digest"
require "sqlite3"

RSpec.describe Catalog::Services::SqliteExporter, type: :model do
  let(:reference_path) { Rails.root.join("docs/refs/catalog.db") }

  describe ".call" do
    it "exports all reference IDs and later catalog rows with exact values and associations" do
      original_hash = Digest::SHA256.file(reference_path).hexdigest
      Catalog::Services::ReferenceCatalogLoader.call
      added = FactoryBot.create(:catalog_product, name: "O'Reilly 12.9\"; legacy", brand: nil, category: nil)
      association = FactoryBot.create(:catalog_seller_product, product: added,
        seller_name: "Seller/*legacy*/", seller_product_id: "001-A")

      bytes = described_class.call
      Tempfile.create([ "export-spec", ".db" ]) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        database = SQLite3::Database.new(file.path)
        begin
          expect(database.execute("SELECT Id, Name, Brand, Category FROM Product ORDER BY Id")).to eq(
            Catalog::Models::Product.order(:id).pluck(:id, :name, :brand, :category))
          expect(database.execute("SELECT Id, SellerName, ProductId, SellerProductId FROM SellerProduct ORDER BY Id")).to eq(
            Catalog::Models::SellerProduct.order(:id).pluck(:id, :seller_name, :product_id, :seller_product_id))
          expect(database.execute("SELECT COUNT(*) FROM Product").flatten).to eq([ 976 ])
          expect(database.execute("SELECT SellerProductId FROM SellerProduct WHERE Id = ?", [ association.id ])).to eq([ [ "001-A" ] ])
          expect(database.table_info("SellerProduct").find { |column| column["name"] == "SellerProductId" }["type"].upcase).to eq("TEXT")
          expect(database.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name").flatten).to eq(%w[Product SellerProduct])
          expect(database.get_first_value("PRAGMA integrity_check")).to eq("ok")
          expect(database.execute("PRAGMA foreign_key_check")).to be_empty
          database.execute("PRAGMA foreign_keys = ON")
          expect {
            database.execute("INSERT INTO SellerProduct (SellerName, ProductId, SellerProductId) VALUES (?, ?, ?)",
              [ "Seller/*legacy*/", 999_999, "new-id" ])
          }.to raise_error(SQLite3::ConstraintException)
          database.execute("INSERT INTO Product (Id, Name) VALUES (?, ?)", [ 999_998, "Constraint probe" ])
          expect {
            database.execute("INSERT INTO SellerProduct (SellerName, ProductId, SellerProductId) VALUES (?, ?, ?)",
              [ association.seller_name, 999_998, association.seller_product_id ])
          }.to raise_error(SQLite3::ConstraintException)
          expect {
            database.execute("INSERT INTO SellerProduct (SellerName, ProductId, SellerProductId) VALUES (?, ?, ?)",
              [ association.seller_name, added.id, "other-id" ])
          }.to raise_error(SQLite3::ConstraintException)
        ensure
          database.close
        end
      end
      expect(Digest::SHA256.file(reference_path).hexdigest).to eq(original_hash)
    end

    it "returns complete independent files on repeated calls" do
      FactoryBot.create(:catalog_product, name: "First")
      paths = []
      allow(Tempfile).to receive(:create).and_wrap_original do |original, *arguments, &block|
        original.call(*arguments) do |file|
          paths << file.path
          block.call(file)
        end
      end
      first = described_class.call
      second = described_class.call

      expect(first).to start_with("SQLite format 3\x00")
      expect(second).to eq(first)
      expect(paths.length).to eq(2)
      expect(paths.all? { |path| !File.exist?(path) }).to be(true)
      expect(Catalog::Models::Product.count).to eq(1)
    end

    it "removes the temporary database after an insert failure without changing catalog rows" do
      product = FactoryBot.create(:catalog_product)
      paths = []
      allow(Tempfile).to receive(:create).and_wrap_original do |original, *arguments, &block|
        original.call(*arguments) do |file|
          paths << file.path
          block.call(file)
        end
      end
      exporter = described_class.new
      allow(described_class).to receive(:new).and_return(exporter)
      allow(exporter).to receive(:insert_products).and_raise(SQLite3::SQLException, "write failed")

      expect { described_class.call }.to raise_error(described_class::Error, /write failed/)
      expect(paths).not_to be_empty
      expect(paths.all? { |path| !File.exist?(path) }).to be(true)
      expect(product.reload).to be_present
    end
  end
end
