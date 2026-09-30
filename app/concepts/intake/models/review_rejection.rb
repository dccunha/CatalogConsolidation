# typed: true

module Intake
  module Models
    class ReviewRejection < ApplicationRecord
      self.table_name = "intake_review_rejections"

      belongs_to :review_candidate, class_name: "Intake::Models::ReviewCandidate", inverse_of: :review_rejection

      validates :reviewer, :reason, presence: true
      validates :rejected_at, presence: true
      validates :review_candidate_id, uniqueness: true

      def readonly?
        persisted?
      end
    end
  end
end
