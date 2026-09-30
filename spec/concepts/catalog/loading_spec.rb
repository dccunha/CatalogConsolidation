require "rails_helper"

RSpec.describe "Catalog concept loading", type: :model do
  it "eager loads the role namespaces from the concept root" do
    concept_root = Rails.root.join("app/concepts")

    expect(Rails.application.paths["app/concepts"].to_a).to include(concept_root.to_s)
    expect(Rails.application.paths["app/concepts"]).to be_eager_load
    expect { Rails.application.eager_load! }.not_to raise_error
    expect(Catalog::Models::Product.name).to eq("Catalog::Models::Product")
    expect(Catalog::Models::SellerProduct.name).to eq("Catalog::Models::SellerProduct")
    expect(Catalog::Controllers::BaseController.name).to eq("Catalog::Controllers::BaseController")
  end
end
