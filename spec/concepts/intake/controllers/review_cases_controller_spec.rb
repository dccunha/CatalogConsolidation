require "rails_helper"

RSpec.describe Intake::Controllers::ReviewCasesController, type: :request do
  let(:row) do
    { "Id" => "0007", "SellerName" => "Gadget <script>alert(1)</script>",
      "Name" => "Camera Canon EOS R6", "Brand" => "Canon", "Category" => "Photo" }
  end
  let!(:product) do
    FactoryBot.create(:catalog_product, name: "Camera Canon EOS R6", brand: "Canon", category: "Photography")
  end

  def import(source, source_name: "review.json")
    result = Intake::Services::ImportProcessor.call(json: [ source ].to_json, source_name: source_name)
    Intake::Models::Batch.find(result.batch_id)
  end

  def page
    Nokogiri::HTML(response.body)
  end

  describe "GET /review_cases" do
    it "shows a clear empty state and labeled filters" do
      get review_cases_path

      expect(response).to have_http_status(:ok)
      expect(page.at_css(".empty-state").text).to include("No cases match these filters")
      expect(page.css(".filter-panel label").map(&:text)).to eq([ "Case status", "Import batch", "Seller" ])
      expect(page.css(".filter-panel button, .filter-panel input[type='submit']").map { |node| node["value"] || node.text }).to include("Apply filters")
    end

    it "filters status, seller, and rerun batch membership by referenced row results" do
      first = import(row)
      first_case = first.row_results.sole.review_case
      rerun = import(row, source_name: "rerun.json")
      other = import(row.merge("Id" => "other", "SellerName" => "Other Seller"))
      other_case = other.row_results.sole.review_case

      get review_cases_path(batch_id: rerun.id, seller_name: row.fetch("SellerName"))
      expect(page.css("tbody th a").map(&:text)).to eq([ "Case ##{first_case.id}" ])
      expect(page.css("tbody td").map(&:text).join).not_to include("Case ##{other_case.id}")
      expect(page.at_css("select[name='batch_id'] option[selected]")["value"]).to eq(rerun.id.to_s)
      expect(page.at_css("select[name='seller_name'] option[selected]")["value"]).to eq(row.fetch("SellerName"))

      first_case.update!(status: "resolved")
      get review_cases_path
      expect(page.css("tbody th a").map(&:text)).to eq([ "Case ##{other_case.id}" ])
      get review_cases_path(status: "resolved", batch_id: first.id)
      expect(page.css("tbody th a").map(&:text)).to eq([ "Case ##{first_case.id}" ])
      get review_cases_path(status: "superseded")
      expect(page.css("tbody th a")).to be_empty
    end

    it "keeps an invalid batch filter empty without a database cast error" do
      import(row)

      get review_cases_path(batch_id: "bad-id")

      expect(response).to have_http_status(:ok)
      expect(page.at_css(".empty-state").text).to include("No cases match")
    end
  end

  describe "GET /review_cases/:id" do
    it "shows original values, ranked evidence, conflicts, and safe source text" do
      Catalog::Models::SellerProduct.create!(seller_name: row.fetch("SellerName"), seller_product_id: "OTHER",
        product_id: product.id)
      batch = import(row)
      review_case = batch.row_results.sole.review_case

      get review_case_path(review_case)

      expect(response).to have_http_status(:ok)
      expect(page.at_css(".case-summary").text).to include("pending", "Review reason")
      expect(page.css(".identity-table").first.text).to include("Photo", "photo")
      expect(page.css(".candidate-card h3").map(&:text)).to eq([ "Rank 1 · Product ##{product.id}" ])
      expect(page.at_css(".candidate-card").text).to include("100.0%", "category", "Photography", "photography")
      expect(page.css(".conflict-note").map(&:text).join).to include("seller ID OTHER", "product ##{product.id}")
      expect(page.at_css(".source-detail pre").text).to include(row.fetch("SellerName"))
      expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(page.css("form[action*='review_cases']")).to be_empty
    end

    it "shows corrections and saved action history apart from import-time outcomes" do
      first = import(row)
      review_case = first.row_results.sole.review_case
      candidate = review_case.review_candidates.sole
      second = import(row, source_name: "again.json")
      now = Time.current.change(usec: 0)
      Intake::Models::ReviewCorrection.create!(review_case: review_case, reviewer: "Old reviewer",
        corrected_at: now, corrected_input: row.merge("Category" => "Photography"),
        corrected_comparison: { "name" => "camera canon eos r6", "brand" => "canon", "category" => "photography" })
      Intake::Models::ReviewRejection.create!(review_candidate: candidate, reviewer: "Old reviewer",
        reason: "Wrong model", rejected_at: now)
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Saved reviewer",
        result: "linked", product_id: product.id, reason: "Confirmed match", decided_at: now)
      review_case.update!(status: "resolved")

      get review_case_path(review_case)

      expect(page.css(".identity-table")[1].text).to include("Photography", "photography")
      expect(page.at_css(".case-summary").text).to include("Linked", "Saved reviewer", "Confirmed match")
      expect(page.at_css(".history-list").text).to include("Old reviewer", "Wrong model", "Saved reviewer")
      expect(page.css("[aria-labelledby='imports-heading'] tbody tr").size).to eq(2)
      expect(page.css("[aria-labelledby='imports-heading'] tbody tr").map(&:text).join).to include("Batch ##{first.id}", "Batch ##{second.id}", "Pending review")
      expect(page.css("[aria-labelledby='imports-heading'] tbody tr").map(&:text).join).not_to include("Linked")
    end

    it "orders interleaved reviewer actions by time with stable ties" do
      FactoryBot.create(:catalog_product, name: "Camera Canon EOS R6", brand: "Canon", category: "Electronics")
      batch = import(row)
      review_case = batch.row_results.sole.review_case
      first_candidate, second_candidate = review_case.review_candidates.order(:rank).to_a
      decided_product = FactoryBot.create(:catalog_product, name: "New camera", brand: "Canon", category: "Photo")
      first_time = Time.current.change(usec: 0)
      second_time = first_time + 1.minute
      decision_time = second_time + 1.minute
      Intake::Models::ReviewRejection.create!(review_candidate: first_candidate, reviewer: "Rejection one",
        reason: "Wrong category", rejected_at: first_time)
      Intake::Models::ReviewRejection.create!(review_candidate: second_candidate, reviewer: "Rejection two",
        reason: "Wrong edition", rejected_at: second_time)
      Intake::Models::ReviewCorrection.create!(review_case: review_case, reviewer: "Correction reviewer",
        corrected_at: second_time, corrected_input: row.merge("Category" => "Photo and Video"),
        corrected_comparison: { "name" => "camera canon eos r6", "brand" => "canon", "category" => "photo and video" })
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Decision reviewer",
        result: "created", product_id: decided_product.id, reason: "No suitable catalog product", decided_at: decision_time)
      review_case.update!(status: "resolved")

      get review_case_path(review_case)

      expect(page.css(".history-list li").map { |item| item.text.squish }).to eq([
        "Product ##{first_candidate.product_id} rejected by Rejection one at #{first_time.strftime('%Y-%m-%d %H:%M %Z')}: Wrong category",
        "Correction by Correction reviewer at #{second_time.strftime('%Y-%m-%d %H:%M %Z')}.",
        "Product ##{second_candidate.product_id} rejected by Rejection two at #{second_time.strftime('%Y-%m-%d %H:%M %Z')}: Wrong edition",
        "Final decision: Created, product ##{decided_product.id}, by Decision reviewer at #{decision_time.strftime('%Y-%m-%d %H:%M %Z')}: No suitable catalog product."
      ])
    end

    it "keeps a superseded case accessible and explains absent candidates" do
      blank_brand = row.merge("Id" => "no-brand", "Name" => "Unlisted item", "Brand" => nil)
      batch = import(blank_brand)
      review_case = batch.row_results.sole.review_case

      get review_case_path(review_case)
      expect(page.at_css("[aria-labelledby='candidates-heading'] .empty-state").text).to include("remains pending review")

      review_case.update!(status: "superseded")

      get review_case_path(review_case)

      expect(response).to have_http_status(:ok)
      expect(page.at_css(".case-summary").text).to include("historical case", "superseded")
      expect(page.at_css("[aria-labelledby='candidates-heading'] .empty-state").text).to include("The case was superseded")
      expect(page.at_css("[aria-labelledby='candidates-heading'] .empty-state").text).not_to include("needs an explicit reviewer decision")
      expect(page.at_css(".history-list")).to be_nil
      get review_cases_path(status: "superseded")
      expect(page.css("tbody th a").map(&:text)).to eq([ "Case ##{review_case.id}" ])
    end

    it "does not ask for another decision when a no-candidate case is resolved" do
      blank_brand = row.merge("Id" => "resolved-no-candidate", "Name" => "Unlisted item", "Brand" => nil)
      batch = import(blank_brand)
      review_case = batch.row_results.sole.review_case
      created_product = FactoryBot.create(:catalog_product, name: "Unlisted item", brand: "Canon", category: "Photo")
      Intake::Models::ReviewCorrection.create!(review_case: review_case, reviewer: "Saved reviewer",
        corrected_at: Time.current, corrected_input: blank_brand.merge("Brand" => "Canon"),
        corrected_comparison: { "name" => "unlisted item", "brand" => "canon", "category" => "photo" })
      Intake::Models::ReviewDecision.create!(review_case: review_case, reviewer: "Saved reviewer",
        result: "created", product_id: created_product.id, decided_at: Time.current)
      review_case.update!(status: "resolved")

      get review_case_path(review_case)

      expect(page.at_css("[aria-labelledby='candidates-heading'] .empty-state").text).to include("This case has a final decision")
      expect(page.at_css("[aria-labelledby='candidates-heading'] .empty-state").text).not_to include("needs an explicit reviewer decision")
    end
  end
end
