require "rails_helper"
require "tempfile"

RSpec.describe "Browser acceptance journeys", type: :system do
  before do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1100 ] do |options|
      options.binary = "/usr/bin/chromium"
      %w[--no-sandbox --disable-dev-shm-usage].each { |argument| options.add_argument(argument) }
    end
  end

  def source(id:, name:, brand: "Canon", category: "Photo", seller: "Browser Seller")
    { "Id" => id, "SellerName" => seller, "Name" => name, "Brand" => brand, "Category" => category }
  end

  def upload_rows(rows)
    Tempfile.create([ "acceptance", ".json" ]) do |file|
      file.write(rows.to_json)
      file.flush
      visit root_path
      attach_file "Seller JSON file", file.path
      click_button "Upload and process"
      expect(page).to have_css(".results-section")
    end
  end

  def screenshot(name)
    return unless ENV["T14_CAPTURE_SCREENSHOTS"] == "1"

    File.binwrite(Rails.root.join("docs/tasks/screenshots/#{name}.png"),
      page.driver.browser.screenshot_as(:png))
  end

  it "uploads mixed outcomes, corrects a candidate, approves it, and shows immutable results after a rerun" do
    product = FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon",
      category: "Photography")
    review = source(id: "review", name: "Canon Camera")
    exact = review.merge("Id" => "exact", "SellerName" => "Other Browser Seller", "Category" => "Photography")
    created = source(id: "created", name: "Unlisted desk lamp", brand: "BrightCo", category: "Home")
    invalid = source(id: "invalid", name: nil)
    rows = [ exact, invalid, review, created ]

    upload_rows(rows)

    expect(page.evaluate_script("typeof Turbo")).to eq("object")
    expect(page.evaluate_script("typeof Stimulus")).to eq("object")
    expect(page).to have_css(".results-section tbody tr", count: 4)
    totals = page.all(".summary-grid > div").to_h do |item|
      [ item.find("dt").text, item.find("dd").text.to_i ]
    end
    expect(totals).to eq("Input rows" => 4, "Linked" => 1, "Created" => 1,
      "Already imported" => 0, "Pending review" => 1, "Failed" => 1)
    screenshot("t14-browser-results")
    batch = Intake::Models::Batch.sole
    review_case = Intake::Models::ReviewCase.sole
    within ".results-section tbody tr:nth-child(3)" do
      click_link "Case ##{review_case.id}"
    end
    expect(page).to have_content("Candidate evidence")
    expect(page).to have_content("Photography")
    expect(page).to have_content("Photo")
    fill_in "Category", with: "Photography"
    click_button "Save correction and rematch"
    expect(page).to have_content("Comparison updated")
    expect(page).to have_content("Pending")
    click_button "Approve product ##{product.id}"
    expect(page).to have_content("approved and linked")
    expect(page).to have_content("Final decision: Linked")
    screenshot("t14-browser-decision")
    expect(Intake::Models::RowResult.find_by!(batch: batch, source_position: 3).reload.outcome).to eq("pending_review")

    upload_rows(rows)

    expect(page).to have_css(".results-section tbody tr", count: 4)
    expect(page).to have_content("Already imported")
    expect(Intake::Models::ReviewCase.count).to eq(1)
    expect(Catalog::Models::SellerProduct.where(seller_name: review.fetch("SellerName"),
      seller_product_id: review.fetch("Id")).sole.product_id).to eq(product.id)
    click_link "Review cases in this batch"
    select "Resolved", from: "Case status"
    select review.fetch("SellerName"), from: "Seller"
    click_button "Apply filters"
    expect(page).to have_link("Case ##{review_case.id}")
  end

  it "rejects an unsuitable candidate and explicitly creates a product after correction" do
    product = FactoryBot.create(:catalog_product, name: "Canon Camera", brand: "Canon",
      category: "Photography")
    incomplete = source(id: "new", name: "Canon Camera", brand: nil)
    upload_rows([ incomplete ])
    review_case = Intake::Models::ReviewCase.sole
    click_link "Case ##{review_case.id}"

    fill_in "Reason for rejecting product ##{product.id}", with: "Different model"
    click_button "Reject product ##{product.id}"
    expect(page).to have_content("Product ##{product.id} rejected")
    expect(page).to have_content("Complete Brand and Category")
    fill_in "Brand", with: "Other Brand"
    fill_in "Name", with: "Different camera kit"
    click_button "Save correction and rematch"
    expect(page).to have_content("Ready for explicit creation")
    click_button "Create new product and link seller item"

    expect(page).to have_content("created and linked after review")
    expect(page).to have_content("Final decision: Created")
    expect(review_case.reload.status).to eq("resolved")
    expect(review_case.review_decision.product_id).not_to eq(product.id)
    expect(review_case.source_input).to eq(incomplete)
    expect(Intake::Models::RowResult.first.outcome).to eq("pending_review")
  end

  %w[keep replace].each do |choice|
    it "chooses #{choice} for a same-seller listing conflict and preserves the result on rerun" do
      old = source(id: "old", name: "Camera One")
      incoming = old.merge("Id" => "incoming")
      original = Intake::Services::ImportProcessor.call(json: [ old ].to_json, source_name: "old.json")
      product_id = original.rows.sole.product_id
      pending = Intake::Services::ImportProcessor.call(json: [ incoming ].to_json, source_name: "incoming.json")
      review_case = Intake::Models::ReviewCase.find(pending.rows.sole.review_case_id)

      visit review_case_path(review_case)
      if choice == "keep"
        click_button "Keep existing ID old; decline incoming ID incoming"
      else
        click_button "Replace ID old with incoming ID incoming"
      end

      expect(page).to have_content("Final decision:")
      expect(review_case.reload.status).to eq("resolved")
      associations = Catalog::Models::SellerProduct.where(seller_name: old.fetch("SellerName"))
      expect(associations.count).to eq(1)
      expect(associations.sole.product_id).to eq(product_id)
      expect(associations.sole.seller_product_id).to eq(choice == "keep" ? "old" : "incoming")
      rerun = Intake::Services::ImportProcessor.call(json: [ old, incoming ].to_json,
        source_name: "rerun.json")
      expect(rerun.rows.map(&:outcome)).to eq(%w[already_imported already_imported])
      expect(rerun.rows.map(&:product_id)).to eq(choice == "keep" ? [ product_id, nil ] : [ nil, product_id ])
      expect(Catalog::Models::SellerProduct.where(seller_name: old.fetch("SellerName")).count).to eq(1)
      screenshot("t14-browser-#{choice}-conflict")
    end
  end
end
