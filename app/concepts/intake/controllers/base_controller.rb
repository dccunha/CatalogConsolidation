# typed: true

module Intake
  module Controllers
    class BaseController < ApplicationController
      extend T::Sig

      abstract!

      prepend_view_path Rails.root.join("app/concepts/intake/views")

      sig { returns(T::Array[String]) }
      def self.local_prefixes
        super.map { |prefix| prefix.delete_prefix("intake/controllers/") }
      end
    end
  end
end
