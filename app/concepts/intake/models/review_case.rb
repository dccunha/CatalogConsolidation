# typed: true

module Intake
  module Models
    class ReviewCase < ApplicationRecord
      extend T::Sig

      self.table_name = "intake_review_cases"
      attr_readonly :seller_item_id, :batch_id, :source_position, :source_input, :source_comparison

      belongs_to :seller_item, class_name: "Intake::Models::SellerItem", inverse_of: :review_cases
      belongs_to :batch, class_name: "Intake::Models::Batch", inverse_of: :review_cases
      has_many :row_results, class_name: "Intake::Models::RowResult", foreign_key: :review_case_id,
        inverse_of: :review_case, dependent: :restrict_with_exception
      has_many :review_candidates, class_name: "Intake::Models::ReviewCandidate", foreign_key: :review_case_id,
        inverse_of: :review_case, dependent: :restrict_with_exception
      has_many :review_corrections, class_name: "Intake::Models::ReviewCorrection", foreign_key: :review_case_id,
        inverse_of: :review_case, dependent: :restrict_with_exception
      has_one :review_decision, class_name: "Intake::Models::ReviewDecision", foreign_key: :review_case_id,
        inverse_of: :review_case, dependent: :restrict_with_exception

      validates :status, inclusion: { in: %w[pending resolved superseded] }
      validates :reason, presence: true
      validates :source_input, :source_comparison, presence: true
      validates :source_position, numericality: { only_integer: true, greater_than: 0 }
      validates :seller_item_id, uniqueness: { conditions: -> { where(status: %w[pending resolved]) } },
        if: :active?

      sig { returns(T::Boolean) }
      def active?
        status == "pending" || status == "resolved"
      end

      sig { returns(T::Boolean) }
      def actionable?
        status == "pending"
      end
    end
  end
end
