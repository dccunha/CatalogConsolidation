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

  def thread_result(thread)
    Timeout.timeout(10) { thread.value }
  end

  def stop_threads(*threads)
    threads.compact.each do |thread|
      thread.join(5)
      thread.kill if thread.alive?
    end
  end

  def wait_for_advisory_block(pid)
    Timeout.timeout(5) do
      loop do
        activity = Intake::Models::SellerItem.connection.select_one(
          "SELECT wait_event_type, wait_event FROM pg_stat_activity WHERE pid = #{pid}")
        break if activity == { "wait_event_type" => "Lock", "wait_event" => "advisory" }

        sleep 0.01
      end
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

  it "serializes first-sight imports of the same key into one pending case" do
    incomplete = row.merge("Brand" => nil)
    entered = Queue.new
    release = Queue.new
    attempting = Queue.new
    first_call = true
    guard = Mutex.new
    allow(described_class).to receive(:lock_seller_key).and_wrap_original do |original, valid|
      if Thread.current[:t08_second_import]
        pid = Intake::Models::SellerItem.connection.select_value("SELECT pg_backend_pid()").to_i
        attempting << pid
      end
      original.call(valid)
    end
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
      Thread.current[:t08_second_import] = true
      import_row(incomplete)
    end
    second_pid = Timeout.timeout(5) { attempting.pop }
    wait_for_advisory_block(second_pid)
    expect(second_thread).to be_alive
    release << true
    results = [ thread_result(first_thread), thread_result(second_thread) ]

    expect(results.map { |result| result.rows.first.outcome }).to eq(%w[pending_review pending_review])
    expect(results.map { |result| result.rows.first.review_case_id }.uniq.length).to eq(1)
    expect(Intake::Models::SellerItem.count).to eq(1)
    expect(Intake::Models::ReviewCase.count).to eq(1)
    expect(Catalog::Models::SellerProduct.count).to eq(0)
  ensure
    release&.push(true)
    stop_threads(first_thread, second_thread)
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
    results = threads.map { |thread| thread_result(thread) }
    cases = Intake::Models::ReviewCase.order(:id).to_a

    expect(results.map { |result| result.rows.first.outcome }).to eq(%w[pending_review pending_review])
    expect(results.map { |result| result.rows.first.review_case_id }.uniq.length).to eq(2)
    expect(cases.map(&:status)).to eq(%w[superseded pending])
    expect(Intake::Models::SellerItem.sole.product_id).to eq(product_id)
    expect(Catalog::Models::SellerProduct.sole.product_id).to eq(product_id)
    expect(Intake::Models::SellerItem.sole.active_source_comparison).to eq(cases.last.source_comparison)
  ensure
    2.times { go&.push(true) }
    stop_threads(*threads) if threads
  end
end
