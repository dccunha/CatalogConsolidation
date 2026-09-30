require "rails_helper"
require Rails.root.join("db/migrate/20260930000002_allow_control_escapes_in_intake_audit")

RSpec.describe AllowControlEscapesInIntakeAudit, type: :model do
  def audit_row(input)
    batch = Intake::Models::Batch.create!(source_name: "migration.json", input_count: 1, created_at: Time.current)
    Intake::Models::RowResult.create!(batch: batch, source_position: 1,
      input_json: JSON.generate(input), outcome: "failed", reason: "audit only")
  end

  it "migrates an existing ordinary audit row without changing its source" do
    input = { "Id" => "before", "Name" => "ordinary" }
    row = audit_row(input)
    migration = described_class.new

    migration.down
    expect(JSON.parse(row.reload.input_json)).to eq(input)
    migration.up
    expect(JSON.parse(row.reload.input_json)).to eq(input)
  end

  it "refuses to restore the jsonb check while an escaped NUL audit row exists" do
    row = audit_row("Id" => "unsafe\u0000id")

    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration, /escaped NUL/)
    expect(JSON.parse(row.reload.input_json).fetch("Id")).to eq("unsafe\u0000id")
  end
end
