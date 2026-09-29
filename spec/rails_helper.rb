require "spec_helper"
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort "RSpec must not run in production" if Rails.env.production?

require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before do
    Bullet.start_request
  end

  config.after do
    begin
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
    ensure
      Bullet.end_request
    end
  end
end
