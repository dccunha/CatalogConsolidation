# typed: true

module Catalog
  module Controllers
    class BaseController < ApplicationController
      extend T::Sig

      abstract!

      prepend_view_path Rails.root.join("app/concepts/catalog/views")

      sig { returns(T::Array[String]) }
      def self.local_prefixes
        super.map { |prefix| prefix.delete_prefix("catalog/controllers/") }
      end
    end
  end
end
