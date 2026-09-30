require "rails_helper"
require "sqlite3"
require "tempfile"

RSpec.describe Intake::Controllers::CatalogExportsController, type: :request do
  self.use_transactional_tests = false

  after do
    Intake::Models::RowResult.delete_all
    Intake::Models::ReviewRejection.delete_all
    Intake::Models::ReviewCandidate.delete_all
    Intake::Models::ReviewCorrection.delete_all
    Intake::Models::ReviewDecision.delete_all
    Intake::Models::ReviewCase.delete_all
    Intake::Models::SellerItem.delete_all
    Intake::Models::Batch.delete_all
    Catalog::Models::SellerProduct.delete_all
    Catalog::Models::Product.delete_all
  end

  def import_row(id:, name:, brand: "Example brand")
    row = { "Id" => id, "SellerName" => "Export Seller", "Name" => name,
      "Brand" => brand, "Category" => "Home" }
    Intake::Services::ImportProcessor.call(json: [ row ].to_json, source_name: "export-spec.json")
  end

  def summary_counts
    Nokogiri::HTML(response.body).css(".summary-grid > div").to_h do |item|
      [ item.at_css("dt").text.strip, item.at_css("dd").text.strip ]
    end
  end

  describe "GET /catalog/export" do
    it "shows counts, a download link, and navigation when the queue is clear" do
      product = FactoryBot.create(:catalog_product)
      FactoryBot.create(:catalog_seller_product, product: product)

      get catalog_export_path

      expect(response).to have_http_status(:ok)
      expect(summary_counts).to eq("Products" => "1", "Seller products" => "1", "Pending reviews" => "0")
      expect(response.body).to include("Download catalog-updated.db", catalog_export_download_path)
      expect(response.body).to include("Export catalog")
    end

    it "hides the download and links the queue while any case is pending" do
      product = FactoryBot.create(:catalog_product)
      FactoryBot.create(:catalog_seller_product, product: product)
      import_row(id: "pending", name: "Incomplete item", brand: nil)

      get catalog_export_path

      expect(summary_counts).to eq("Products" => "1", "Seller products" => "1", "Pending reviews" => "1")
      expect(response.body).to include("Resolve all active pending reviews", "Open review queue")
      expect(response.body).not_to include("Download catalog-updated.db")
    end

    it "explains historical failures without blocking the download" do
      import_row(id: "failed", name: "Bad; item")

      get catalog_export_path

      expect(response.body).to include("Some historical import rows failed", "unless a later successful import")
      expect(response.body).to include("Download catalog-updated.db")
    end
  end

  describe "GET /catalog/export/download" do
    it "rechecks pending cases for direct requests and releases after resolution" do
      import_row(id: "pending", name: "Incomplete item", brand: nil)
      review_case = Intake::Models::ReviewCase.sole

      get catalog_export_download_path
      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("active pending review case", "Open review queue")
      expect(response.headers["Content-Disposition"]).to be_nil

      review_case.update!(status: "resolved")
      get catalog_export_download_path
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include('attachment; filename="catalog-updated.db"')
      expect(response.body).to start_with("SQLite format 3\x00")
    end

    it "enables the page and direct download when only superseded cases remain" do
      import_row(id: "superseded", name: "Incomplete item", brand: nil)
      Intake::Models::ReviewCase.sole.update!(status: "superseded")

      get catalog_export_path
      expect(response).to have_http_status(:ok)
      expect(summary_counts).to eq("Products" => "0", "Seller products" => "0", "Pending reviews" => "0")
      expect(response.body).to include("Download catalog-updated.db", catalog_export_download_path)

      get catalog_export_download_path
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include('attachment; filename="catalog-updated.db"')
      expect(response.body).to start_with("SQLite format 3\x00")
    end

    it "downloads an intact snapshot repeatedly when failures are historical" do
      FactoryBot.create(:catalog_product, name: "New catalog item", brand: nil, category: nil)
      import_row(id: "failed", name: "Bad; item")

      get catalog_export_download_path
      first = response.body
      get catalog_export_download_path
      second = response.body

      expect(response).to have_http_status(:ok)
      expect(first).to eq(second)
      Tempfile.create([ "download-spec", ".db" ]) do |file|
        file.binmode
        file.write(second)
        file.flush
        database = SQLite3::Database.new(file.path)
        begin
          expect(database.execute("SELECT Name, Brand, Category FROM Product")).to eq([ [ "New catalog item", nil, nil ] ])
          expect(database.get_first_value("PRAGMA integrity_check")).to eq("ok")
        ensure
          database.close
        end
      end
    end

    it "uses the pending-check snapshot for later Catalog reads" do
      initial = FactoryBot.create(:catalog_product, name: "Before snapshot")
      allow(Catalog::Public::Exports).to receive(:sqlite_snapshot).and_wrap_original do |original|
        Thread.new do
          product = Catalog::Models::Product.create!(name: "After snapshot")
          Catalog::Models::SellerProduct.create!(product: product, seller_name: "Concurrent",
            seller_product_id: "later")
        end.value
        original.call
      end

      get catalog_export_download_path

      expect(response).to have_http_status(:ok)
      Tempfile.create([ "snapshot-spec", ".db" ]) do |file|
        file.binmode
        file.write(response.body)
        file.flush
        database = SQLite3::Database.new(file.path)
        begin
          expect(database.execute("SELECT Id, Name FROM Product")).to eq([ [ initial.id, "Before snapshot" ] ])
          expect(database.execute("SELECT COUNT(*) FROM SellerProduct").flatten).to eq([ 0 ])
        ensure
          database.close
        end
      end
      expect(Catalog::Models::Product.count).to eq(2)
    end

    it "returns no attachment when SQLite generation fails" do
      allow(Catalog::Public::Exports).to receive(:sqlite_snapshot).and_raise(
        Catalog::Services::SqliteExporter::Error, "broken")

      get catalog_export_download_path

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("could not be generated")
      expect(response.headers["Content-Disposition"]).to be_nil
    end
  end
end
