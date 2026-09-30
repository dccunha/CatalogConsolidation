# typed: true

module Catalog
  module Public
    class Exports
      extend T::Sig

      sig { returns(String) }
      def self.sqlite_snapshot
        Catalog::Services::SqliteExporter.call
      end
    end
  end
end
