# typed: true

require "json"
require "open3"

module Catalog
  module Services
    class ReferenceCatalogLoader
      extend T::Sig

      class Error < StandardError; end
      class InputError < Error; end
      class ConflictError < Error; end

      class ReferenceProduct < T::Struct
        const :id, Integer
        const :name, String
        const :brand, T.nilable(String)
        const :category, T.nilable(String)
      end

      SOURCE_QUERY = <<~SQL.freeze
        SELECT json_object(
          'products', json((SELECT json_group_array(json_object(
            'id', Id, 'name', Name, 'brand', Brand, 'category', Category
          )) FROM Product)),
          'seller_count', (SELECT COUNT(*) FROM SellerProduct)
        );
      SQL

      sig { params(path: T.any(String, Pathname)).returns(Integer) }
      def self.call(path: Rails.root.join("docs/refs/catalog.db"))
        new(path: path).call
      end

      sig { params(path: T.any(String, Pathname)).void }
      def initialize(path:)
        @path = path.to_s
      end

      sig { returns(Integer) }
      def call
        products = read_products
        Catalog::Models::Product.transaction do
          # Serialize catalog writers while comparing and inserting reference IDs.
          Catalog::Models::Product.connection.execute("LOCK TABLE products IN SHARE ROW EXCLUSIVE MODE")
          missing = missing_products(products)
          insert_products(missing)
          advance_sequence
          missing.length
        end
      end

      private

      sig { params(products: T::Array[ReferenceProduct]).returns(T::Array[ReferenceProduct]) }
      def missing_products(products)
        existing = Catalog::Models::Product.where(id: products.map(&:id)).index_by(&:id)
        products.reject do |product|
          current = existing[product.id]
          next false unless current

          unless current.name == product.name && current.brand == product.brand && current.category == product.category
            raise ConflictError, "Reference product ID #{product.id} conflicts with an existing catalog product"
          end

          true
        end
      end

      sig { params(products: T::Array[ReferenceProduct]).void }
      def insert_products(products)
        products.each_slice(100) do |batch|
          rows = batch.map do |product|
            { id: product.id, name: product.name, brand: product.brand, category: product.category }
          end
          Catalog::Models::Product.insert_all!(rows, record_timestamps: false)
        end
      end

      sig { returns(T::Array[ReferenceProduct]) }
      def read_products
        raise InputError, "Reference catalog is missing or unreadable: #{@path}" unless File.file?(@path) && File.readable?(@path)

        output, error, status = Open3.capture3("sqlite3", "-readonly", @path, SOURCE_QUERY)
        raise InputError, "Cannot read reference catalog #{@path}: #{error.strip}" unless status.success?

        parse_products(output)
      end

      sig { params(output: String).returns(T::Array[ReferenceProduct]) }
      def parse_products(output)
        source = JSON.parse(output)
        products = source.fetch("products")
        unless products.is_a?(Array) && products.length == 975 && source.fetch("seller_count") == 0
          raise InputError, "Reference catalog must contain 975 products and no seller associations"
        end

        products.map { |row| product_from(row) }
      rescue JSON::ParserError, KeyError => error
        raise InputError, "Invalid reference catalog #{@path}: #{error.message}"
      end

      sig { params(row: T::Hash[String, T.any(Integer, String, NilClass)]).returns(ReferenceProduct) }
      def product_from(row)
        id = row.fetch("id")
        name = row.fetch("name")
        brand = row.fetch("brand")
        category = row.fetch("category")
        unless id.is_a?(Integer) && name.is_a?(String) && (brand.nil? || brand.is_a?(String)) &&
            (category.nil? || category.is_a?(String))
          raise InputError, "Reference catalog contains invalid product values"
        end

        ReferenceProduct.new(id: id, name: name, brand: brand, category: category)
      end

      sig { void }
      def advance_sequence
        Catalog::Models::Product.connection.execute(<<~SQL)
          SELECT setval(
            pg_get_serial_sequence('products', 'id'),
            GREATEST((SELECT MAX(id) FROM products), (SELECT last_value FROM products_id_seq)),
            true
          )
        SQL
      end
    end
  end
end
