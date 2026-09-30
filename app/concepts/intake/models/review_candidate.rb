# typed: true

module Intake
  module Models
    class ReviewCandidate < ApplicationRecord
      self.table_name = "intake_review_candidates"

      belongs_to :review_case, class_name: "Intake::Models::ReviewCase", inverse_of: :review_candidates
      has_one :review_rejection, class_name: "Intake::Models::ReviewRejection", foreign_key: :review_candidate_id,
        inverse_of: :review_candidate, dependent: :restrict_with_exception

      validates :rank, numericality: { only_integer: true, greater_than: 0 }
      validates :evidence_revision, numericality: { only_integer: true, greater_than: 0 }
      validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
      validates :original, :comparison, presence: true
      validates :product_id, presence: true
      validates :rank, uniqueness: { scope: [ :review_case_id, :evidence_revision ] }
      validates :product_id, uniqueness: { scope: [ :review_case_id, :evidence_revision ] }

      def readonly?
        persisted?
      end
    end
  end
end
