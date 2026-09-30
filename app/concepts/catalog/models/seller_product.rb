# typed: true

module Catalog
  module Models
    class SellerProduct < ApplicationRecord
      self.table_name = "seller_products"

      belongs_to :product, class_name: "Catalog::Models::Product", inverse_of: :seller_products

      validates :seller_name, :seller_product_id, presence: true
      validates :seller_product_id, uniqueness: { scope: :seller_name }
      validates :product_id, uniqueness: { scope: :seller_name }
    end
  end
end
