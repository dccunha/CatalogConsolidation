# typed: true

module Intake
  module Reviewer
    extend T::Sig

    DEFAULT_NAME = "Local reviewer"

    sig { returns(String) }
    def self.name
      Rails.configuration.x.intake.reviewer_name.to_s.strip.presence || DEFAULT_NAME
    end
  end
end
