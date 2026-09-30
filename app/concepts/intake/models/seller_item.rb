# typed: true

module Intake
  module Models
    class SellerItem < ApplicationRecord
      extend T::Sig

      self.table_name = "intake_seller_items"

      has_many :review_cases, class_name: "Intake::Models::ReviewCase", foreign_key: :seller_item_id,
        inverse_of: :seller_item, dependent: :restrict_with_exception

      validates :seller_name, :seller_product_id, presence: true
      validates :active_source_input, :active_source_comparison, presence: true
      validates :seller_product_id, uniqueness: { scope: :seller_name }
      validates :resolution, inclusion: { in: %w[pending linked created declined displaced] }

      sig { params(seller_name: String, seller_product_id: String).returns(T.nilable(SellerItem)) }
      def self.find_exact(seller_name:, seller_product_id:)
        find_by(seller_name: seller_name, seller_product_id: seller_product_id)
      end

      sig { returns(T.nilable(ReviewCase)) }
      def active_case
        review_cases.where(status: %w[pending resolved]).first
      end
    end
  end
end
