class AllowControlEscapesInIntakeAudit < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :intake_row_results, name: "intake_row_results_input_valid_json"
    add_check_constraint :intake_row_results, "input_json IS JSON",
      name: "intake_row_results_input_valid_json"
  end

  def down
    incompatible_jsonb = connection.select_value(<<~SQL)
      SELECT EXISTS (
        SELECT 1 FROM intake_row_results
        WHERE NOT pg_input_is_valid(input_json, 'jsonb')
      )
    SQL
    if incompatible_jsonb
      raise ActiveRecord::IrreversibleMigration,
        "Intake audit contains JSON text incompatible with jsonb; restoring the old constraint would reject valid source rows"
    end

    remove_check_constraint :intake_row_results, name: "intake_row_results_input_valid_json"
    add_check_constraint :intake_row_results, "input_json::jsonb IS NOT NULL",
      name: "intake_row_results_input_valid_json"
  end
end
