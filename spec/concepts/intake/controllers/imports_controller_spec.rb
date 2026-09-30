require "rails_helper"

RSpec.describe Intake::Controllers::ImportsController, type: :request do
  let(:source_row) do
    { "Id" => "001", "SellerName" => "O'Reilly <script>alert(1)</script>",
      "Name" => "Desk lamp", "Brand" => "BrightCo", "Category" => "Home" }
  end

  def upload(json, filename: "seller.json")
    Rack::Test::UploadedFile.new(StringIO.new(json), "application/json", original_filename: filename)
  end

  describe "GET /" do
    it "offers a labeled upload form and batch history from the application entry point" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Upload seller products", "Seller JSON file", "View recorded batches")
      expect(response.body).to include('type="file"', 'required="required"')
    end
  end

  describe "GET /batches" do
    it "explains how to begin when no batches exist" do
      get batches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No batches yet", "Upload a file")
    end
  end

  describe "POST /import" do
    it "persists an import and redirects to its results" do
      post import_path, params: { file: upload([ source_row ].to_json, filename: "first.json") }

      batch = Intake::Models::Batch.sole
      expect(response).to redirect_to(batch_path(batch))
      expect(batch.source_name).to eq("first.json")
      expect(batch.row_results.sole.outcome).to eq("created")

      follow_redirect!
      expect(response.body).to include("Batch ##{batch.id} results", "Input rows", "Created", "Desk lamp")
    end

    it "shows the missing-file error without creating a batch" do
      post import_path

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Choose a JSON file to upload.")
      expect(Intake::Models::Batch.count).to eq(0)
    end

    it "shows malformed and non-array errors without creating batches" do
      post import_path, params: { file: upload("{bad") }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Import file contains malformed JSON")

      post import_path, params: { file: upload("{}") }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Import file must contain a JSON array")
      expect(Intake::Models::Batch.count).to eq(0)
    end

    it "records mixed outcomes and safely renders source text, seller keys, and reasons" do
      existing = FactoryBot.create(:catalog_product, name: "Desk lamp", brand: "BrightCo", category: "Home")
      invalid = source_row.merge("Id" => "bad", "Name" => nil)
      pending = source_row.merge("Id" => "pending", "Name" => "Unlisted cable", "Brand" => nil)
      payload = [ source_row, invalid, pending ]

      post import_path, params: { file: upload(payload.to_json) }
      batch = Intake::Models::Batch.sole
      expect(batch.row_results.order(:source_position).pluck(:outcome)).to eq(%w[linked failed pending_review])
      expect(batch.row_results.count).to eq(3)

      get batch_path(batch)
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      totals = page.css(".summary-grid > div").to_h do |item|
        [ item.at_css("dt").text.strip, item.at_css("dd").text.strip.to_i ]
      end
      expect(totals).to eq({ "Input rows" => 3, "Linked" => 1, "Created" => 0,
        "Already imported" => 0, "Pending review" => 1, "Failed" => 1 })

      rows = page.css(".results-section tbody tr")
      expect(rows.map { |item| item.at_css("th[scope='row']").text.strip }).to eq(%w[1 2 3])
      cells = rows.map { |item| item.css("td").map { |cell| cell.text.strip } }
      expect(cells[0]).to include(include(source_row["SellerName"], "ID: 001"), "Linked",
        existing.id.to_s, "—", include("Linked to exact catalog product #{existing.id}"))
      expect(cells[1]).to include(include(source_row["SellerName"], "ID: bad"), "Failed",
        "—", "—", include("Name is required"))
      review_case_id = batch.row_results.find_by!(source_position: 3).review_case_id
      expect(cells[2]).to include(include(source_row["SellerName"], "ID: pending"), "Pending review",
        "—", review_case_id.to_s, include("Pending review: incomplete metadata"))
      expect(response.body).to include("O&#39;Reilly &lt;script&gt;alert(1)&lt;/script&gt;")
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("View source row")
      expect(response.body).not_to include("href=\"/review")
    end

    it "keeps the first batch audit when the same file is uploaded again" do
      json = [ source_row ].to_json
      post import_path, params: { file: upload(json) }
      first = Intake::Models::Batch.sole

      post import_path, params: { file: upload(json) }
      second = Intake::Models::Batch.order(:id).last

      expect(Intake::Models::Batch.count).to eq(2)
      expect(first.row_results.sole.outcome).to eq("created")
      expect(second.row_results.sole.outcome).to eq("already_imported")
      expect(second.row_results.sole.product_id).to eq(first.row_results.sole.product_id)

      get batches_path
      expect(response.body).to include("Batch ##{first.id}", "Batch ##{second.id}")
      get batch_path(first)
      expect(response.body).to include("Created", "View source row")
    end

    it "shows an empty-results message for an empty valid array" do
      post import_path, params: { file: upload("[]") }
      get batch_path(Intake::Models::Batch.sole)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("This valid JSON array contained no rows")
      totals = Nokogiri::HTML(response.body).css(".summary-grid dd").map { |item| item.text.strip.to_i }
      expect(totals).to eq([ 0, 0, 0, 0, 0, 0 ])
    end
  end
end
