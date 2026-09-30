require "rails_helper"
require "digest"
require "fileutils"
require "tmpdir"

RSpec.describe Catalog::Services::ReferenceCatalogLoader, type: :model do
  let(:reference_path) { Rails.root.join("docs/refs/catalog.db") }

  describe ".call" do
    it "loads all reference values, preserves product 2, and advances new product IDs" do
      checksum = Digest::SHA256.file(reference_path).hexdigest

      expect(described_class.call).to eq(975)
      expect(Catalog::Models::Product.count).to eq(975)
      expect(Catalog::Models::Product.find(2).attributes.slice("name", "brand", "category")).to eq(
        "name" => "Smartphone Galaxy S23", "brand" => "Samsung", "category" => "Electronics"
      )
      expect(Catalog::Models::Product.find(975).id).to eq(975)
      output, error, status = Open3.capture3("sqlite3", "-readonly", "-json", reference_path.to_s,
        "SELECT Id, Name, Brand, Category FROM Product ORDER BY Id")
      expect(status.success?).to be(true), error
      source_rows = JSON.parse(output).map { |row| row.values_at("Id", "Name", "Brand", "Category") }
      expect(Catalog::Models::Product.order(:id).pluck(:id, :name, :brand, :category)).to eq(source_rows)
      expect(FactoryBot.create(:catalog_product).id).to be > 975
      expect(Digest::SHA256.file(reference_path).hexdigest).to eq(checksum)
    end

    it "skips identical products on a rerun without changing unrelated catalog data" do
      other = FactoryBot.create(:catalog_product, id: 2000)

      expect(described_class.call).to eq(975)
      expect(described_class.call).to eq(0)
      expect(Catalog::Models::Product.count).to eq(976)
      expect(other.reload.name).to eq(other.name)
      expect(FactoryBot.create(:catalog_product).id).to be > 2000
    end

    it "fails clearly on a conflicting ID without loading any other reference products" do
      existing = FactoryBot.create(:catalog_product, id: 2, name: "Local product")

      expect { described_class.call }.to raise_error(described_class::ConflictError, /ID 2/)
      expect(Catalog::Models::Product.count).to eq(1)
      expect(existing.reload.name).to eq("Local product")
    end

    it "rejects missing input before writing products" do
      expect { described_class.call(path: Rails.root.join("tmp/missing-catalog.db")) }
        .to raise_error(described_class::InputError, /missing or unreadable/)
      expect(Catalog::Models::Product.count).to eq(0)
    end

    it "rejects unreadable input before writing products" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "catalog.db")
        FileUtils.cp(reference_path, path)
        File.chmod(0o000, path)

        expect { described_class.call(path: path) }.to raise_error(described_class::InputError, /missing or unreadable/)
        expect(Catalog::Models::Product.count).to eq(0)
      end
    end

    it "rolls back earlier batches when a later product cannot be inserted" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "catalog.db")
        FileUtils.cp(reference_path, path)
        _output, error, status = Open3.capture3("sqlite3", path, "UPDATE Product SET Name = ' ' WHERE Id = 975")
        expect(status.success?).to be(true), error

        expect { described_class.call(path: path) }.to raise_error(ActiveRecord::StatementInvalid)
        expect(Catalog::Models::Product.count).to eq(0)
      end
    end

    it "rejects a source with seller associations" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "catalog.db")
        FileUtils.cp(reference_path, path)
        _output, error, status = Open3.capture3("sqlite3", path,
          "INSERT INTO SellerProduct (SellerName, ProductId, SellerProductId) VALUES ('Seller', 1, 7)")
        expect(status.success?).to be(true), error

        expect { described_class.call(path: path) }.to raise_error(described_class::InputError, /no seller associations/)
        expect(Catalog::Models::Product.count).to eq(0)
      end
    end

    it "rejects a damaged SQLite file before writing products" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "catalog.db")
        File.write(path, "not a SQLite database")

        expect { described_class.call(path: path) }.to raise_error(described_class::InputError, /Cannot read reference catalog/)
        expect(Catalog::Models::Product.count).to eq(0)
      end
    end

    it "rejects an incomplete reference product set" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "catalog.db")
        FileUtils.cp(reference_path, path)
        _output, error, status = Open3.capture3("sqlite3", path, "DELETE FROM Product WHERE Id = 975")
        expect(status.success?).to be(true), error

        expect { described_class.call(path: path) }.to raise_error(described_class::InputError, /975 products/)
        expect(Catalog::Models::Product.count).to eq(0)
      end
    end
  end
end
