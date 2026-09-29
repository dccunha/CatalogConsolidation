require "rails_helper"

RSpec.describe "Health endpoint", type: :request do
  it "responds when the application boots" do
    host! "localhost"
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
