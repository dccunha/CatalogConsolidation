require "rails_helper"

RSpec.describe Intake::Reviewer do
  describe ".name" do
    it "returns the configured local reviewer name" do
      allow(Rails.configuration.x.intake).to receive(:reviewer_name).and_return("  Dana  ")

      expect(described_class.name).to eq("Dana")
    end

    it "uses the local default for a blank configured name" do
      allow(Rails.configuration.x.intake).to receive(:reviewer_name).and_return("  ")

      expect(described_class.name).to eq("Local reviewer")
    end
  end
end
