# typed: true

module Intake
  module Models
    class ReviewDecision < ApplicationRecord
      self.table_name = "intake_review_decisions"

      belongs_to :review_case, class_name: "Intake::Models::ReviewCase", inverse_of: :review_decision
      validates :reviewer, presence: true
      validates :decided_at, presence: true
      validates :result, inclusion: { in: %w[linked created kept_existing] }
      validates :review_case_id, uniqueness: true

      def readonly?
        persisted?
      end
    end
  end
end
