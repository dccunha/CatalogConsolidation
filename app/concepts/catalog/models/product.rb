# typed: true

module Catalog
  module Models
    class Product < ApplicationRecord
      self.table_name = "products"

      has_many :seller_products, class_name: "Catalog::Models::SellerProduct", foreign_key: :product_id,
        inverse_of: :product, dependent: :restrict_with_exception

      validates :name, presence: true
    end
  end
end
