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
        return Invalid.new(input: element, errors: [ Error.new(field: nil, code: :not_an_object) ]) unless element.is_a?(Hash)

        errors = validate_fields(element)
        return Invalid.new(input: element, errors: errors) unless errors.empty?

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
        Source.new(seller_product_id: T.cast(element["Id"], String),
          seller_name: T.cast(element["SellerName"], String), name: T.cast(element["Name"], String),
          brand: T.cast(element["Brand"], T.nilable(String)),
          category: T.cast(element["Category"], T.nilable(String)))
      end
      private_class_method :source_from

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
