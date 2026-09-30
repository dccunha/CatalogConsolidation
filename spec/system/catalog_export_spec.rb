require "rails_helper"

RSpec.describe "Catalog export journey", type: :system do
  self.use_transactional_tests = false

  before do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ] do |options|
      options.binary = "/usr/bin/chromium"
      %w[--no-sandbox --disable-dev-shm-usage].each { |argument| options.add_argument(argument) }
    end
  end

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

  it "shows the review block, then presents the available catalog download" do
    Catalog::Services::ReferenceCatalogLoader.call
    row = { "Id" => "pending-export", "SellerName" => "Browser Seller", "Name" => "Unknown cable",
      "Brand" => nil, "Category" => "Accessories" }
    Intake::Services::ImportProcessor.call(json: [ row ].to_json, source_name: "browser-export.json")

    visit root_path
    click_link "Export catalog"
    counts = page.all(".summary-grid > div").to_h do |item|
      [ item.find("dt").text, item.find("dd").text.to_i ]
    end
    expect(counts).to eq("Products" => 975, "Seller products" => 0, "Pending reviews" => 1)
    expect(page).to have_content("Resolve all active pending reviews")
    expect(page).to have_link("Open review queue")
    expect(page).not_to have_link("Download catalog-updated.db")

    Intake::Models::ReviewCase.sole.update!(status: "resolved")
    visit catalog_export_path
    counts = page.all(".summary-grid > div").to_h do |item|
      [ item.find("dt").text, item.find("dd").text.to_i ]
    end
    expect(counts).to eq("Products" => 975, "Seller products" => 0, "Pending reviews" => 0)
    expect(page).to have_link("Download catalog-updated.db", href: catalog_export_download_path)
    if ENV["T17_CAPTURE_SCREENSHOTS"] == "1"
      File.binwrite(Rails.root.join("docs/tasks/screenshots/t17-export-ready.png"),
        page.driver.browser.screenshot_as(:png))
    end
  end
end
