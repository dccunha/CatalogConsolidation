require "rails_helper"

RSpec.describe Catalog::Controllers::BaseController, type: :request do
  describe "concept routing and views" do
    before do
      controller = Class.new(described_class) do
        def index
          render :index
        end
      end
      stub_const("Catalog::Controllers::LookupController", controller)
      controller.prepend_view_path Rails.root.join("spec/fixtures/concepts/catalog/views")

      Rails.application.routes.draw do
        get "/concept-view-probe", to: "catalog/controllers/lookup#index"
      end
    end

    after do
      Rails.application.reload_routes!
    end

    it "loads a namespaced controller and its owning context template" do
      host! "localhost"
      get "/concept-view-probe"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Catalog view lookup fixture")
      expect(described_class.view_paths.paths.map(&:to_s)).to include(Rails.root.join("app/concepts/catalog/views").to_s)
    end
  end
end
