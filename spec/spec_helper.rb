ENV["RAILS_ENV"] ||= "test"

require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch
  coverage_dir "coverage/ruby"
  cover "{app,lib}/**/*.rb"
  minimum_coverage line: 90, branch: 80
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.syntax = :expect
  end
end
