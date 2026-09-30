# typed: true

module Intake
  module Models
    class AppendOnlyRecord < ApplicationRecord
      self.abstract_class = true

      def readonly?
        persisted?
      end

      # Active Record's #delete skips readonly? and callbacks.
      def delete
        raise ActiveRecord::ReadOnlyRecord, "Historical Intake records cannot be deleted" if persisted?

        super
      end
    end
  end
end
