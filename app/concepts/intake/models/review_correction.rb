# typed: true

module Intake
  module Models
    class ReviewCorrection < ApplicationRecord
      self.table_name = "intake_review_corrections"

      belongs_to :review_case, class_name: "Intake::Models::ReviewCase", inverse_of: :review_corrections

      validates :reviewer, presence: true
      validates :corrected_input, :corrected_comparison, :corrected_at, presence: true

      def readonly?
        persisted?
      end
    end
  end
end
