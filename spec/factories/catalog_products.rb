FactoryBot.define do
  factory :catalog_product, class: "Catalog::Models::Product" do
    sequence(:name) { |number| "Product #{number}" }
    brand { "Example brand" }
    category { "Example category" }
  end

  factory :catalog_seller_product, class: "Catalog::Models::SellerProduct" do
    sequence(:seller_product_id) { |number| "item-#{number}" }
    seller_name { "Seller" }
    association :product, factory: :catalog_product
  end
end
