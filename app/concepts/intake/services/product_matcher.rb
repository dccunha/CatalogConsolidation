# typed: true

module Intake
  module Services
    # Read-only matching evidence for one validated seller row, against current Catalog records.
    class ProductMatcher
      extend T::Sig

      class Association < T::Struct
        const :id, Integer
        const :product_id, Integer
        const :seller_name, String
        const :seller_product_id, String
      end

      class ProductValues < T::Struct
        const :name, String
        const :brand, T.nilable(String)
        const :category, T.nilable(String)
      end

      class Candidate < T::Struct
        const :product_id, Integer
        const :score, Float
        const :original, ProductValues
        const :comparison, ComparisonNormalizer::Identity
        const :differing_fields, T::Array[Symbol]
        const :brand_matches, T::Boolean
        const :category_matches, T::Boolean
        const :seller_product_conflict, T.nilable(Association)
      end

      class Result < T::Struct
        const :source, RowValidator::Source
        const :comparison, ComparisonNormalizer::Identity
        const :recommendation, Symbol
        const :product_id, T.nilable(Integer)
        const :reasons, T::Array[Symbol]
        const :candidates, T::Array[Candidate]
        const :seller_item_association, T.nilable(Association)
      end

      sig { params(valid: RowValidator::Valid).returns(Result) }
      def self.call(valid:)
        associations = Catalog::Models::SellerProduct.where(seller_name: valid.source.seller_name).to_a
        seller_item = associations.find { |association| association.seller_product_id == valid.source.seller_product_id }
        candidates = candidates_for(valid, associations)
        result_for(valid, candidates, seller_item)
      end

      sig do
        params(valid: RowValidator::Valid, candidates: T::Array[Candidate],
          seller_item: T.nilable(Catalog::Models::SellerProduct)).returns(Result)
      end
      def self.result_for(valid, candidates, seller_item)
        exact = candidates.select { |candidate| candidate.comparison == valid.comparison }
        reasons = review_reasons(valid, exact, candidates, seller_item)
        recommendation = recommendation_for(exact, reasons)
        Result.new(source: valid.source, comparison: valid.comparison, recommendation: recommendation,
          product_id: recommendation == :link ? exact.first&.product_id : nil, reasons: reasons.freeze,
          candidates: candidates, seller_item_association: snapshot_association(seller_item))
      end
      private_class_method :result_for

      sig do
        params(valid: RowValidator::Valid, associations: T::Array[Catalog::Models::SellerProduct]).returns(T::Array[Candidate])
      end
      def self.candidates_for(valid, associations)
        by_product = associations.index_by(&:product_id)
        candidates = Catalog::Models::Product.find_each.filter_map do |product|
          candidate_for(product, valid.comparison, by_product[product.id], valid.source.seller_product_id)
        end
        candidates.sort_by! { |candidate| candidate_rank(candidate) }
        candidates.freeze
      end
      private_class_method :candidates_for

      sig { params(candidate: Candidate).returns([ Float, Integer, Integer, Integer ]) }
      def self.candidate_rank(candidate)
        [ -candidate.score, candidate.brand_matches ? 0 : 1, candidate.category_matches ? 0 : 1,
          candidate.product_id ]
      end
      private_class_method :candidate_rank

      sig { params(exact: T::Array[Candidate], reasons: T::Array[Symbol]).returns(Symbol) }
      def self.recommendation_for(exact, reasons)
        return :review if reasons.any?

        exact.empty? ? :create : :link
      end
      private_class_method :recommendation_for

      sig do
        params(product: Catalog::Models::Product, comparison: ComparisonNormalizer::Identity,
          association: T.nilable(Catalog::Models::SellerProduct), seller_product_id: String).returns(T.nilable(Candidate))
      end
      def self.candidate_for(product, comparison, association, seller_product_id)
        normalized = ComparisonNormalizer.call(name: product.name, brand: product.brand, category: product.category)
        score = similarity(comparison.name, normalized.name)
        return unless credible?(comparison, normalized, score)

        Candidate.new(product_id: product.id, score: score,
          original: product_values(product), comparison: normalized,
          differing_fields: differing_fields(comparison, normalized),
          brand_matches: matching_nonblank?(comparison.brand, normalized.brand),
          category_matches: matching_nonblank?(comparison.category, normalized.category),
          seller_product_conflict: product_conflict(association, seller_product_id))
      end
      private_class_method :candidate_for

      sig do
        params(left: ComparisonNormalizer::Identity, right: ComparisonNormalizer::Identity,
          score: Float).returns(T::Boolean)
      end
      def self.credible?(left, right, score)
        left.name == right.name || (matching_nonblank?(left.brand, right.brand) && score >= 0.80)
      end
      private_class_method :credible?

      sig { params(left: T.nilable(String), right: T.nilable(String)).returns(T::Boolean) }
      def self.matching_nonblank?(left, right)
        !left.nil? && left == right
      end
      private_class_method :matching_nonblank?

      sig { params(product: Catalog::Models::Product).returns(ProductValues) }
      def self.product_values(product)
        ProductValues.new(name: product.name.dup.freeze, brand: product.brand&.dup&.freeze,
          category: product.category&.dup&.freeze)
      end
      private_class_method :product_values

      sig do
        params(left: ComparisonNormalizer::Identity, right: ComparisonNormalizer::Identity).returns(T::Array[Symbol])
      end
      def self.differing_fields(left, right)
        differences = T.let([], T::Array[Symbol])
        differences << :name unless left.name == right.name
        differences << :brand unless left.brand == right.brand
        differences << :category unless left.category == right.category
        differences.freeze
      end
      private_class_method :differing_fields

      sig do
        params(association: T.nilable(Catalog::Models::SellerProduct), seller_product_id: String).returns(T.nilable(Association))
      end
      def self.product_conflict(association, seller_product_id)
        return unless association && association.seller_product_id != seller_product_id

        snapshot_association(association)
      end
      private_class_method :product_conflict

      sig do
        params(valid: RowValidator::Valid, exact: T::Array[Candidate], candidates: T::Array[Candidate],
          seller_item: T.nilable(Catalog::Models::SellerProduct)).returns(T::Array[Symbol])
      end
      def self.review_reasons(valid, exact, candidates, seller_item)
        reasons = T.let([], T::Array[Symbol])
        reasons << :incomplete_metadata if valid.review_required?
        reasons << :seller_item_taken if seller_item
        reasons << :multiple_exact_matches if exact.length > 1
        reasons << :seller_product_taken if exact.any?(&:seller_product_conflict)
        reasons << :candidate_review if exact.empty? && candidates.any?
        reasons
      end
      private_class_method :review_reasons

      sig { params(association: T.nilable(Catalog::Models::SellerProduct)).returns(T.nilable(Association)) }
      def self.snapshot_association(association)
        return unless association

        Association.new(id: association.id, product_id: association.product_id,
          seller_name: association.seller_name.dup.freeze,
          seller_product_id: association.seller_product_id.dup.freeze)
      end
      private_class_method :snapshot_association

      sig { params(left: String, right: String).returns(Float) }
      def self.similarity(left, right)
        left_chars = left.each_char.to_a
        right_chars = right.each_char.to_a
        length = [ left_chars.length, right_chars.length ].max
        return 1.0 if length.zero?

        1.0 - (levenshtein_distance(left_chars, right_chars).to_f / length)
      end
      private_class_method :similarity

      sig { params(left: T::Array[String], right: T::Array[String]).returns(Integer) }
      def self.levenshtein_distance(left, right)
        previous = T.let((0..right.length).to_a, T::Array[Integer])
        left.each_with_index do |left_char, left_index|
          previous = distance_row(previous, left_char, left_index, right)
        end
        previous.fetch(right.length)
      end
      private_class_method :levenshtein_distance

      sig do
        params(previous: T::Array[Integer], left_char: String, left_index: Integer,
          right: T::Array[String]).returns(T::Array[Integer])
      end
      def self.distance_row(previous, left_char, left_index, right)
        current = T.let([ left_index + 1 ], T::Array[Integer])
        right.each_with_index do |right_char, right_index|
          substitution = left_char == right_char ? 0 : 1
          current << [ previous.fetch(right_index + 1) + 1, current.fetch(right_index) + 1,
            previous.fetch(right_index) + substitution ].min
        end
        current
      end
      private_class_method :distance_row
    end
  end
end
