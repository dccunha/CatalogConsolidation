# typed: true

module Catalog
  module Public
    class Writes
      extend T::Sig

      class ConflictError < StandardError
        extend T::Sig

        sig { returns(Symbol) }
        attr_reader :kind

        sig { returns(T.nilable(Integer)) }
        attr_reader :existing_association_id

        sig { params(kind: Symbol, message: String, existing_association_id: T.nilable(Integer)).void }
        def initialize(kind:, message:, existing_association_id: nil)
          @kind = kind
          @existing_association_id = existing_association_id
          super(message)
        end
      end

      sig do
        params(product_id: Integer, seller_name: String, seller_product_id: String)
          .returns(Catalog::Models::SellerProduct)
      end
      def self.link(product_id:, seller_name:, seller_product_id:)
        write do
          Catalog::Models::Product.find(product_id)
          create_association(product_id: product_id, seller_name: seller_name, seller_product_id: seller_product_id)
        end
      end

      sig do
        params(name: String, brand: T.nilable(String), category: T.nilable(String), seller_name: String,
          seller_product_id: String).returns(Catalog::Models::SellerProduct)
      end
      def self.create_with_association(name:, brand:, category:, seller_name:, seller_product_id:)
        write do
          product = Catalog::Models::Product.create!(name: name, brand: brand, category: category)
          create_association(product_id: product.id, seller_name: seller_name, seller_product_id: seller_product_id)
        end
      end

      sig do
        params(association_id: Integer, product_id: Integer, seller_product_id: String)
          .returns(Catalog::Models::SellerProduct)
      end
      def self.reassign(association_id:, product_id:, seller_product_id:)
        write do
          association = Catalog::Models::SellerProduct.lock.find(association_id)
          Catalog::Models::Product.find(product_id)
          check_conflicts(seller_name: association.seller_name, seller_product_id: seller_product_id,
            product_id: product_id, excluding_id: association.id)
          association.update!(product_id: product_id, seller_product_id: seller_product_id)
          association
        end
      end

      sig do
        params(association_id: Integer, expected_product_id: Integer,
          expected_seller_product_id: String).returns(Catalog::Models::SellerProduct)
      end
      def self.retire_listing(association_id:, expected_product_id:, expected_seller_product_id:)
        write do
          association = Catalog::Models::SellerProduct.lock.find(association_id)
          check_expected_state(association, product_id: expected_product_id,
            seller_product_id: expected_seller_product_id)
          association.delete
          association
        end
      end

      sig do
        params(association_id: Integer, expected_product_id: Integer, expected_seller_product_id: String,
          name: String, brand: T.nilable(String), category: T.nilable(String))
          .returns(Catalog::Models::SellerProduct)
      end
      def self.create_for_association(association_id:, expected_product_id:, expected_seller_product_id:,
        name:, brand:, category:)
        write do
          association = Catalog::Models::SellerProduct.lock.find(association_id)
          check_expected_state(association, product_id: expected_product_id,
            seller_product_id: expected_seller_product_id)
          product = Catalog::Models::Product.create!(name: name, brand: brand, category: category)
          association.update!(product_id: product.id)
          association
        end
      end

      sig do
        params(survivor_association_id: Integer, displaced_association_id: Integer,
          expected_survivor_product_id: Integer, expected_displaced_product_id: Integer,
          expected_survivor_seller_product_id: String, expected_displaced_seller_product_id: String)
          .returns(Catalog::Models::SellerProduct)
      end
      def self.replace_listing(survivor_association_id:, displaced_association_id:, expected_survivor_product_id:,
        expected_displaced_product_id:, expected_survivor_seller_product_id:, expected_displaced_seller_product_id:)
        raise ArgumentError, "Survivor and displaced associations must differ" if survivor_association_id == displaced_association_id

        write do
          associations = locked_associations(survivor_association_id, displaced_association_id)
          survivor = associations.fetch(survivor_association_id)
          displaced = associations.fetch(displaced_association_id)
          check_replacement_state(survivor: survivor, displaced: displaced,
            expected_survivor_product_id: expected_survivor_product_id,
            expected_displaced_product_id: expected_displaced_product_id,
            expected_survivor_seller_product_id: expected_survivor_seller_product_id,
            expected_displaced_seller_product_id: expected_displaced_seller_product_id)

          displaced.delete
          check_conflicts(seller_name: survivor.seller_name, seller_product_id: survivor.seller_product_id,
            product_id: displaced.product_id, excluding_id: survivor.id)
          survivor.update!(product_id: displaced.product_id)
          survivor
        end
      end

      sig do
        params(first_id: Integer, second_id: Integer).returns(T::Hash[Integer, Catalog::Models::SellerProduct])
      end
      def self.locked_associations(first_id, second_id)
        [ first_id, second_id ].sort.index_with { |id| Catalog::Models::SellerProduct.lock.find(id) }
      end
      private_class_method :locked_associations

      sig do
        params(survivor: Catalog::Models::SellerProduct, displaced: Catalog::Models::SellerProduct,
          expected_survivor_product_id: Integer, expected_displaced_product_id: Integer,
          expected_survivor_seller_product_id: String, expected_displaced_seller_product_id: String).void
      end
      def self.check_replacement_state(survivor:, displaced:, expected_survivor_product_id:,
        expected_displaced_product_id:, expected_survivor_seller_product_id:, expected_displaced_seller_product_id:)
        check_expected_state(survivor, product_id: expected_survivor_product_id,
          seller_product_id: expected_survivor_seller_product_id)
        check_expected_state(displaced, product_id: expected_displaced_product_id,
          seller_product_id: expected_displaced_seller_product_id)
        return if survivor.seller_name == displaced.seller_name

        raise ConflictError.new(kind: :seller_mismatch,
          message: "Associations #{survivor.id} and #{displaced.id} belong to different sellers")
      end
      private_class_method :check_replacement_state

      sig { params(block: T.proc.returns(Catalog::Models::SellerProduct)).returns(Catalog::Models::SellerProduct) }
      def self.write(&block)
        Catalog::Models::SellerProduct.transaction(requires_new: true, &block)
      rescue ActiveRecord::RecordNotUnique => error
        raise ConflictError.new(kind: :database_unique_conflict,
          message: "Catalog seller association conflicts with a concurrent write: #{error.message}")
      end
      private_class_method :write

      sig do
        params(product_id: Integer, seller_name: String, seller_product_id: String)
          .returns(Catalog::Models::SellerProduct)
      end
      def self.create_association(product_id:, seller_name:, seller_product_id:)
        check_conflicts(seller_name: seller_name, seller_product_id: seller_product_id, product_id: product_id)
        Catalog::Models::SellerProduct.create!(product_id: product_id, seller_name: seller_name,
          seller_product_id: seller_product_id)
      end
      private_class_method :create_association

      sig do
        params(seller_name: String, seller_product_id: String, product_id: Integer, excluding_id: T.nilable(Integer)).void
      end
      def self.check_conflicts(seller_name:, seller_product_id:, product_id:, excluding_id: nil)
        associations = Catalog::Models::SellerProduct.where(seller_name: seller_name)
        associations = associations.where.not(id: excluding_id) if excluding_id
        if (existing = associations.find_by(seller_product_id: seller_product_id))
          raise ConflictError.new(kind: :seller_item_taken,
            message: "Seller item #{seller_name.inspect}/#{seller_product_id.inspect} already belongs to association #{existing.id}",
            existing_association_id: existing.id)
        end
        if (existing = associations.find_by(product_id: product_id))
          raise ConflictError.new(kind: :seller_product_taken,
            message: "Seller #{seller_name.inspect} already offers product #{product_id} as #{existing.seller_product_id.inspect} (association #{existing.id})",
            existing_association_id: existing.id)
        end
      end
      private_class_method :check_conflicts

      sig do
        params(association: Catalog::Models::SellerProduct, product_id: Integer, seller_product_id: String).void
      end
      def self.check_expected_state(association, product_id:, seller_product_id:)
        return if association.product_id == product_id && association.seller_product_id == seller_product_id

        raise ConflictError.new(kind: :stale_association,
          message: "Association #{association.id} changed since review",
          existing_association_id: association.id)
      end
      private_class_method :check_expected_state
    end
  end
end
