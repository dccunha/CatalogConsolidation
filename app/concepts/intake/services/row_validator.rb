# typed: true

module Intake
  module Services
    class RowValidator
      extend T::Sig

      class Source < T::Struct
        const :seller_product_id, String
        const :seller_name, String
        const :name, String
        const :brand, T.nilable(String)
        const :category, T.nilable(String)
      end

      class Error < T::Struct
        const :field, T.nilable(String)
        const :code, Symbol
      end

      class Valid < T::Struct
        extend T::Sig

        const :source, Source
        const :comparison, ComparisonNormalizer::Identity

        sig { returns(T::Boolean) }
        def review_required?
          comparison.brand.nil? || comparison.category.nil?
        end
      end

      class Invalid < T::Struct
        const :input, Object
        const :errors, T::Array[Error]
      end

      sig { params(element: Object).returns(T.any(Valid, Invalid)) }
      def self.call(element)
        unless element.is_a?(Hash)
          return Invalid.new(input: snapshot_json(element),
            errors: [ Error.new(field: nil, code: :not_an_object) ].freeze)
        end

        errors = validate_fields(element)
        return Invalid.new(input: snapshot_json(element), errors: errors.freeze) unless errors.empty?

        source = source_from(element)
        Valid.new(source: source,
          comparison: ComparisonNormalizer.call(name: source.name, brand: source.brand, category: source.category))
      end

      sig { params(element: T::Hash[String, Object]).returns(T::Array[Error]) }
      def self.validate_fields(element)
        errors = T.let([], T::Array[Error])
        check_required(errors, "Id", element["Id"])
        check_required(errors, "SellerName", element["SellerName"])
        check_required(errors, "Name", element["Name"])
        check_optional(errors, "Brand", element["Brand"])
        check_optional(errors, "Category", element["Category"])
        errors
      end
      private_class_method :validate_fields

      sig { params(element: T::Hash[String, Object]).returns(Source) }
      def self.source_from(element)
        Source.new(seller_product_id: source_string(element, "Id"),
          seller_name: source_string(element, "SellerName"), name: source_string(element, "Name"),
          brand: optional_source_string(element, "Brand"),
          category: optional_source_string(element, "Category"))
      end
      private_class_method :source_from

      sig { params(element: T::Hash[String, Object], field: String).returns(String) }
      def self.source_string(element, field)
        T.cast(element[field], String).dup.freeze
      end
      private_class_method :source_string

      sig { params(element: T::Hash[String, Object], field: String).returns(T.nilable(String)) }
      def self.optional_source_string(element, field)
        T.cast(element[field], T.nilable(String))&.dup&.freeze
      end
      private_class_method :optional_source_string

      sig { params(value: Object).returns(Object) }
      def self.snapshot_json(value)
        # JSON leaves are strings or immutable scalars; copy containers and strings for the audit result.
        case value
        when String
          value.dup.freeze
        when Array
          value.map { |item| snapshot_json(item) }.freeze
        when Hash
          value.each_with_object({}) do |(key, item), copy|
            copy[snapshot_json(key)] = snapshot_json(item)
          end.freeze
        else
          value
        end
      end
      private_class_method :snapshot_json

      sig { params(errors: T::Array[Error], field: String, value: Object).void }
      def self.check_required(errors, field, value)
        code = if !value.is_a?(String) && !value.nil?
          :invalid_type
        elsif !value.is_a?(String) || value.gsub(/\p{Space}+/, " ").strip.empty?
          :required
        end
        errors << Error.new(field: field, code: code) if code
      end
      private_class_method :check_required

      sig { params(errors: T::Array[Error], field: String, value: Object).void }
      def self.check_optional(errors, field, value)
        errors << Error.new(field: field, code: :invalid_type) unless value.nil? || value.is_a?(String)
      end
      private_class_method :check_optional
    end
  end
end
