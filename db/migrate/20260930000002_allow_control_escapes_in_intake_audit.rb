class AllowControlEscapesInIntakeAudit < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :intake_row_results, name: "intake_row_results_input_valid_json"
    add_check_constraint :intake_row_results, "input_json IS JSON",
      name: "intake_row_results_input_valid_json"
  end

  def down
    escaped_nul = connection.select_value(<<~SQL)
      SELECT EXISTS (
        SELECT 1 FROM intake_row_results
        WHERE position(chr(92) || 'u0000' in input_json) > 0
      )
    SQL
    if escaped_nul
      raise ActiveRecord::IrreversibleMigration,
        "Intake audit contains escaped NUL; restoring the jsonb constraint would discard valid source rows"
    end

    remove_check_constraint :intake_row_results, name: "intake_row_results_input_valid_json"
    add_check_constraint :intake_row_results, "input_json::jsonb IS NOT NULL",
      name: "intake_row_results_input_valid_json"
  end
end
