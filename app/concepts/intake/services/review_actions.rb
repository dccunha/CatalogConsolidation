# typed: true

module Intake
  module Services
    # Reviewer commands for the ordinary candidate path. Conflict resolution and creation
    # remain separate commands in T12/T13.
    class ReviewActions
      extend T::Sig

      class Result < T::Struct
        extend T::Sig

        const :status, Symbol
        const :message, String

        sig { returns(T::Boolean) }
        def success?
          status == :approved || status == :rejected || status == :corrected
        end
      end

      sig { params(review_case_id: Integer, candidate_id: Integer, evidence_revision: Integer).returns(Result) }
      def self.approve(review_case_id:, candidate_id:, evidence_revision:)
        with_locked_case(review_case_id) do |review_case, seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          valid = current_validation(review_case)
          match = ProductMatcher.call(valid: valid)
          refresh = refresh_if_changed(review_case, match)
          next refresh if refresh

          candidate = actionable_candidate(review_case, candidate_id)
          next invalid_candidate unless candidate

          approve_candidate(review_case, seller_item, candidate, match)
        end
      rescue Catalog::Public::Writes::ConflictError => error
        result(:conflict, "Catalog association changed: #{error.message}. Review the case again.")
      end

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          candidate: Models::ReviewCandidate, match: ProductMatcher::Result).returns(Result)
      end
      def self.approve_candidate(review_case, seller_item, candidate, match)
        return unsupported_conflict if seller_item.product_id || match.seller_item_association ||
          candidate.conflicting_association.present?

        association = Catalog::Public::Writes.link(product_id: candidate.product_id,
          seller_name: seller_item.seller_name, seller_product_id: seller_item.seller_product_id)
        Models::ReviewDecision.create!(review_case: review_case, reviewer: Reviewer.name,
          decided_at: Time.current, result: "linked", product_id: association.product_id,
          reason: "Approved catalog candidate ##{candidate.product_id}")
        seller_item.update!(resolution: "linked", product_id: association.product_id)
        review_case.update!(status: "resolved")
        result(:approved, "Product ##{candidate.product_id} approved and linked.")
      end
      private_class_method :approve_candidate

      sig do
        params(review_case_id: Integer, candidate_id: Integer, evidence_revision: Integer,
          reason: String).returns(Result)
      end
      def self.reject(review_case_id:, candidate_id:, evidence_revision:, reason:)
        return result(:invalid, "Enter a reason for rejecting this candidate.") if reason.strip.empty?

        with_locked_case(review_case_id) do |review_case, _seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          match = ProductMatcher.call(valid: current_validation(review_case))
          refresh = refresh_if_changed(review_case, match)
          next refresh if refresh

          candidate = actionable_candidate(review_case, candidate_id)
          next invalid_candidate unless candidate

          Models::ReviewRejection.create!(review_candidate: candidate, reviewer: Reviewer.name,
            rejected_at: Time.current, reason: reason.strip)
          result(:rejected, "Product ##{candidate.product_id} rejected. Review the remaining candidates.")
        end
      end

      sig do
        params(review_case_id: Integer, evidence_revision: Integer, name: String,
          brand: T.nilable(String), category: T.nilable(String)).returns(Result)
      end
      def self.correct(review_case_id:, evidence_revision:, name:, brand:, category:)
        with_locked_case(review_case_id) do |review_case, _seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          input = current_input(review_case).merge("Name" => name, "Brand" => brand, "Category" => category)
          validation = RowValidator.call(input)
          next result(:invalid, "Enter a name and text values for the comparison fields.") unless
            validation.is_a?(RowValidator::Valid)
          next result(:invalid, "Comparison values have not changed.") if
            comparison_hash(validation) == current_comparison(review_case)

          match = ProductMatcher.call(valid: validation)
          Models::ReviewCorrection.create!(review_case: review_case, reviewer: Reviewer.name,
            corrected_at: Time.current, corrected_input: input,
            corrected_comparison: comparison_hash(validation))
          append_evidence(review_case, match, reason: "Comparison corrected; explicit review still required")
          result(:corrected, "Comparison updated. Review the new evidence before deciding.")
        end
      end

      sig do
        params(review_case_id: Integer, block: T.proc.params(review_case: Models::ReviewCase,
          seller_item: Models::SellerItem).returns(Result)).returns(Result)
      end
      def self.with_locked_case(review_case_id, &block)
        seller_item = Models::SellerItem.find(Models::ReviewCase.find(review_case_id).seller_item_id)
        seller_item.with_lock do
          review_case = Models::ReviewCase.lock.find(review_case_id)
          if !review_case.actionable? || seller_item.resolution != "pending" ||
              seller_item.active_case&.id != review_case.id
            next result(:not_actionable, "This case is no longer pending. No action was saved.")
          end

          block.call(review_case, seller_item)
        end
      end
      private_class_method :with_locked_case

      sig { params(review_case: Models::ReviewCase).returns(T::Hash[String, Object]) }
      def self.current_input(review_case)
        correction = review_case.review_corrections.order(:id).last
        T.cast(correction ? correction.corrected_input : review_case.source_input, T::Hash[String, Object])
      end
      private_class_method :current_input

      sig { params(review_case: Models::ReviewCase).returns(T::Hash[String, T.nilable(String)]) }
      def self.current_comparison(review_case)
        correction = review_case.review_corrections.order(:id).last
        T.cast(correction ? correction.corrected_comparison : review_case.source_comparison,
          T::Hash[String, T.nilable(String)])
      end
      private_class_method :current_comparison

      sig { params(review_case: Models::ReviewCase).returns(RowValidator::Valid) }
      def self.current_validation(review_case)
        validation = RowValidator.call(current_input(review_case))
        raise "Saved review comparison is invalid" unless validation.is_a?(RowValidator::Valid)

        validation
      end
      private_class_method :current_validation

      sig { params(valid: RowValidator::Valid).returns(T::Hash[String, T.nilable(String)]) }
      def self.comparison_hash(valid)
        { "name" => valid.comparison.name, "brand" => valid.comparison.brand,
          "category" => valid.comparison.category }
      end
      private_class_method :comparison_hash

      sig { params(review_case: Models::ReviewCase, match: ProductMatcher::Result).returns(T.nilable(Result)) }
      def self.refresh_if_changed(review_case, match)
        snapshots = review_case.review_candidates.where(evidence_revision: review_case.evidence_revision).order(:rank)
          .map { |candidate| candidate_snapshot(candidate) }
        fresh = match.candidates.each_with_index.map { |candidate, index| match_snapshot(candidate, index + 1) }
        return if snapshots == fresh && review_case.conflicting_association == conflict_hash(match)

        append_evidence(review_case, match, reason: "Catalog evidence changed; review the refreshed candidates")
        result(:stale, "Catalog evidence changed. Review the refreshed candidates before acting.")
      end
      private_class_method :refresh_if_changed

      sig { params(candidate: Models::ReviewCandidate).returns(T::Hash[String, Object]) }
      def self.candidate_snapshot(candidate)
        { "rank" => candidate.rank, "product_id" => candidate.product_id, "score" => candidate.score,
          "original" => candidate.original, "comparison" => candidate.comparison,
          "differing_fields" => candidate.differing_fields,
          "conflicting_association" => candidate.conflicting_association }
      end
      private_class_method :candidate_snapshot

      sig { params(candidate: ProductMatcher::Candidate, rank: Integer).returns(T::Hash[String, Object]) }
      def self.match_snapshot(candidate, rank)
        { "rank" => rank, "product_id" => candidate.product_id, "score" => candidate.score,
          "original" => { "name" => candidate.original.name, "brand" => candidate.original.brand,
            "category" => candidate.original.category },
          "comparison" => { "name" => candidate.comparison.name, "brand" => candidate.comparison.brand,
            "category" => candidate.comparison.category },
          "differing_fields" => candidate.differing_fields.map(&:to_s),
          "conflicting_association" => association_hash(candidate.seller_product_conflict) }
      end
      private_class_method :match_snapshot

      sig { params(review_case: Models::ReviewCase, match: ProductMatcher::Result, reason: String).void }
      def self.append_evidence(review_case, match, reason:)
        revision = review_case.evidence_revision + 1
        match.candidates.each_with_index do |candidate, index|
          snapshot = match_snapshot(candidate, index + 1)
          Models::ReviewCandidate.create!(review_case: review_case, evidence_revision: revision,
            rank: index + 1, product_id: candidate.product_id, score: candidate.score,
            original: snapshot.fetch("original"), comparison: snapshot.fetch("comparison"),
            differing_fields: snapshot.fetch("differing_fields"),
            conflicting_association: snapshot.fetch("conflicting_association"))
        end
        review_case.update!(evidence_revision: revision, conflicting_association: conflict_hash(match),
          reason: reason)
      end
      private_class_method :append_evidence

      sig { params(match: ProductMatcher::Result).returns(T.nilable(T::Hash[String, Object])) }
      def self.conflict_hash(match)
        association = match.seller_item_association || match.candidates.filter_map(&:seller_product_conflict).first
        association_hash(association)
      end
      private_class_method :conflict_hash

      sig { params(association: T.nilable(ProductMatcher::Association)).returns(T.nilable(T::Hash[String, Object])) }
      def self.association_hash(association)
        return unless association

        { "id" => association.id, "product_id" => association.product_id,
          "seller_name" => association.seller_name, "seller_product_id" => association.seller_product_id }
      end
      private_class_method :association_hash

      sig { params(review_case: Models::ReviewCase, candidate_id: Integer).returns(T.nilable(Models::ReviewCandidate)) }
      def self.actionable_candidate(review_case, candidate_id)
        candidate = review_case.review_candidates.find_by(id: candidate_id,
          evidence_revision: review_case.evidence_revision)
        return unless candidate
        return if review_case.review_candidates.joins(:review_rejection).where(product_id: candidate.product_id).exists?

        candidate
      end
      private_class_method :actionable_candidate

      sig { params(status: Symbol, message: String).returns(Result) }
      def self.result(status, message)
        Result.new(status: status, message: message)
      end
      private_class_method :result

      sig { returns(Result) }
      def self.stale_revision
        result(:stale, "This page has older evidence. Reload the case before acting.")
      end
      private_class_method :stale_revision

      sig { returns(Result) }
      def self.invalid_candidate
        result(:invalid, "This candidate is unavailable or was already rejected.")
      end
      private_class_method :invalid_candidate

      sig { returns(Result) }
      def self.unsupported_conflict
        result(:conflict, "This association needs conflict resolution. It cannot be approved here yet.")
      end
      private_class_method :unsupported_conflict
    end
  end
end
