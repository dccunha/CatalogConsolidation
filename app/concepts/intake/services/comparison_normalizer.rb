# typed: true

module Intake
  module Services
    # The same comparison contract applies to seller rows and catalog products.
    class ComparisonNormalizer
      extend T::Sig

      class Identity
        extend T::Sig

        sig { returns(String) }
        attr_reader :name

        sig { returns(T.nilable(String)) }
        attr_reader :brand, :category

        sig { params(name: String, brand: T.nilable(String), category: T.nilable(String)).void }
        def initialize(name:, brand:, category:)
          @name = name.dup.freeze
          @brand = brand&.dup&.freeze
          @category = category&.dup&.freeze
          freeze
        end

        sig { params(other: Object).returns(T::Boolean) }
        def ==(other)
          other.is_a?(Identity) && name == other.name && brand == other.brand && category == other.category
        end

        alias_method :eql?, :==

        sig { returns(Integer) }
        def hash
          [ name, brand, category ].hash
        end
      end

      sig do
        params(name: String, brand: T.nilable(String), category: T.nilable(String)).returns(Identity)
      end
      def self.call(name:, brand:, category:)
        Identity.new(name: normalize(name) || "", brand: normalize(brand), category: normalize(category))
      end

      sig { params(value: T.nilable(String)).returns(T.nilable(String)) }
      def self.normalize(value)
        return if value.nil?

        # Ruby accepts :fold, but Sorbet's core String RBI only declares downcase with zero arguments.
        case_folded = T.cast(T.unsafe(value).downcase(:fold), String)
        folded = case_folded.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
        result = folded.gsub(/\p{Space}+/, " ").strip
        result unless result.empty?
      end
    end
  end
end
