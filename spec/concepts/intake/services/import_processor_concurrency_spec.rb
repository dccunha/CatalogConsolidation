require "rails_helper"
require "timeout"

RSpec.describe Intake::Services::ImportProcessor, type: :model do
  self.use_transactional_tests = false

  let(:row) do
    { "Id" => "concurrent", "SellerName" => "RaceSeller", "Name" => "Race Widget",
      "Brand" => "Acme", "Category" => "Tools" }
  end

  def import_row(input)
    described_class.call(json: [ input ].to_json, source_name: "concurrent.json")
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

  it "serializes first-sight imports of the same key into one pending case" do
    incomplete = row.merge("Brand" => nil)
    entered = Queue.new
    release = Queue.new
    started = Queue.new
    first_call = true
    guard = Mutex.new
    allow(Intake::Services::ProductMatcher).to receive(:call).and_wrap_original do |original, **arguments|
      pause = guard.synchronize do
        current = first_call
        first_call = false
        current
      end
      if pause
        entered << true
        release.pop
      end
      original.call(**arguments)
    end

    first_thread = Thread.new { import_row(incomplete) }
    Timeout.timeout(5) { entered.pop }
    second_thread = Thread.new do
      started << true
      import_row(incomplete)
    end
    Timeout.timeout(5) { started.pop }
    sleep 0.1
    release << true
    results = [ first_thread.value, second_thread.value ]

    expect(results.map { |result| result.rows.first.outcome }).to eq(%w[pending_review pending_review])
    expect(results.map { |result| result.rows.first.review_case_id }.uniq.length).to eq(1)
    expect(Intake::Models::SellerItem.count).to eq(1)
    expect(Intake::Models::ReviewCase.count).to eq(1)
    expect(Catalog::Models::SellerProduct.count).to eq(0)
  ensure
    release&.push(true)
    first_thread&.join(5)
    second_thread&.join(5)
  end

  it "serializes concurrent changed versions and leaves one actionable case" do
    original = import_row(row)
    product_id = original.rows.first.product_id
    ready = Queue.new
    go = Queue.new
    changed = [ row.merge("Brand" => "Other"), row.merge("Category" => "Other") ]
    threads = changed.map do |input|
      Thread.new do
        ready << true
        go.pop
        import_row(input)
      end
    end
    2.times { Timeout.timeout(5) { ready.pop } }
    2.times { go << true }
    results = threads.map(&:value)
    cases = Intake::Models::ReviewCase.order(:id).to_a

    expect(results.map { |result| result.rows.first.outcome }).to eq(%w[pending_review pending_review])
    expect(results.map { |result| result.rows.first.review_case_id }.uniq.length).to eq(2)
    expect(cases.map(&:status)).to eq(%w[superseded pending])
    expect(Intake::Models::SellerItem.sole.product_id).to eq(product_id)
    expect(Catalog::Models::SellerProduct.sole.product_id).to eq(product_id)
    expect(Intake::Models::SellerItem.sole.active_source_comparison).to eq(cases.last.source_comparison)
  ensure
    2.times { go&.push(true) }
    threads&.each { |thread| thread.join(5) }
  end
end
