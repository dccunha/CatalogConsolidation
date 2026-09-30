# typed: true

module Intake
  module Models
    class Batch < ApplicationRecord
      self.table_name = "intake_batches"

      has_many :row_results, class_name: "Intake::Models::RowResult", foreign_key: :batch_id,
        inverse_of: :batch, dependent: :restrict_with_exception
      has_many :review_cases, class_name: "Intake::Models::ReviewCase", foreign_key: :batch_id,
        inverse_of: :batch, dependent: :restrict_with_exception

      validates :source_name, presence: true
      validates :input_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    end
  end
end
