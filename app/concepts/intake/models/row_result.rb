# typed: true

module Intake
  module Models
    class RowResult < AppendOnlyRecord
      self.table_name = "intake_row_results"

      belongs_to :batch, class_name: "Intake::Models::Batch", inverse_of: :row_results
      belongs_to :review_case, class_name: "Intake::Models::ReviewCase", optional: true,
        inverse_of: :row_results

      validates :source_position, numericality: { only_integer: true, greater_than: 0 },
        uniqueness: { scope: :batch_id }
      validates :outcome, inclusion: { in: %w[linked created already_imported pending_review failed] }
      validates :reason, presence: true
      validates :input_json, presence: true
    end
  end
end
