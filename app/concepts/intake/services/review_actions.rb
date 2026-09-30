# typed: true

module Intake
  module Services
    # Reviewer commands for candidate decisions and explicit creation.
    class ReviewActions
      extend T::Sig

      class Result < T::Struct
        extend T::Sig

        const :status, Symbol
        const :message, String

        sig { returns(T::Boolean) }
        def success?
          %i[approved rejected corrected created kept_existing replaced].include?(status)
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

      sig { params(review_case_id: Integer, candidate_id: Integer, evidence_revision: Integer).returns(Result) }
      def self.reassign_candidate(review_case_id:, candidate_id:, evidence_revision:)
        with_locked_case(review_case_id) do |review_case, seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          match = ProductMatcher.call(valid: current_validation(review_case))
          refresh = refresh_if_changed(review_case, match)
          next refresh if refresh
          reassign_current_candidate(review_case, seller_item, candidate_id, match)
        end
      rescue Catalog::Public::Writes::ConflictError => error
        catalog_conflict_result(review_case_id, error)
      end

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          candidate_id: Integer, match: ProductMatcher::Result).returns(Result)
      end
      def self.reassign_current_candidate(review_case, seller_item, candidate_id, match)
        candidate = actionable_candidate(review_case, candidate_id)
        return invalid_candidate unless candidate
        return unsupported_conflict unless match.seller_item_association && candidate.conflicting_association.blank?

        association = locked_current_association(T.must(match.seller_item_association))
        return stale_association(review_case) unless association

        persist_candidate_move(review_case, seller_item, candidate, association)
      end
      private_class_method :reassign_current_candidate

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          candidate: Models::ReviewCandidate, association: Catalog::Models::SellerProduct).returns(Result)
      end
      def self.persist_candidate_move(review_case, seller_item, candidate, association)
        saved = Catalog::Public::Writes.reassign(association_id: association.id,
          product_id: candidate.product_id, seller_product_id: seller_item.seller_product_id)
        finalize_decision(review_case, seller_item, result_name: "linked", product_id: saved.product_id,
          reason: "Explicit reassignment from product ##{association.product_id} to candidate ##{candidate.product_id}")
        result(:approved, "Seller ID #{seller_item.seller_product_id} reassigned to product ##{saved.product_id}.")
      end
      private_class_method :persist_candidate_move

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

      sig { params(review_case: Models::ReviewCase).returns(Symbol) }
      def self.creation_state(review_case:)
        return :not_actionable unless review_case.actionable?

        seller_item = Models::SellerItem.find(review_case.seller_item_id)
        return :not_actionable unless active_pending_case?(review_case, seller_item)
        return :association_conflict if seller_item.product_id || existing_item_conflict?(review_case, seller_item)
        return :incomplete if current_validation(review_case).review_required?

        remaining_candidates?(review_case) ? :candidates : :ready
      end

      sig { params(review_case: Models::ReviewCase).returns(Symbol) }
      def self.reassignment_creation_state(review_case:)
        return :not_actionable unless review_case.actionable?

        seller_item = Models::SellerItem.find(review_case.seller_item_id)
        return :not_actionable unless active_pending_case?(review_case, seller_item)
        return :no_association unless existing_item_conflict?(review_case, seller_item)
        return :incomplete if current_validation(review_case).review_required?

        remaining_candidates?(review_case) ? :candidates : :ready
      end

      sig { params(review_case_id: Integer, evidence_revision: Integer).returns(Result) }
      def self.create_for_reassignment(review_case_id:, evidence_revision:)
        with_locked_case(review_case_id) do |review_case, seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          valid = current_validation(review_case)
          match = ProductMatcher.call(valid: valid)
          refresh = refresh_if_changed(review_case, match)
          next refresh if refresh
          create_reassigned_product(review_case, seller_item, valid, match)
        end
      rescue Catalog::Public::Writes::ConflictError => error
        catalog_conflict_result(review_case_id, error)
      end

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          valid: RowValidator::Valid, match: ProductMatcher::Result).returns(Result)
      end
      def self.create_reassigned_product(review_case, seller_item, valid, match)
        return result(:invalid, "Complete metadata and reject remaining candidates first.") unless
          reassignment_creation_state(review_case: review_case) == :ready
        return unsupported_conflict unless match.seller_item_association

        association = locked_current_association(T.must(match.seller_item_association))
        return stale_association(review_case) unless association

        persist_reassigned_creation(review_case, seller_item, valid, association)
      end
      private_class_method :create_reassigned_product

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          valid: RowValidator::Valid, association: Catalog::Models::SellerProduct).returns(Result)
      end
      def self.persist_reassigned_creation(review_case, seller_item, valid, association)
        saved = Catalog::Public::Writes.create_for_association(association_id: association.id,
          expected_product_id: association.product_id, expected_seller_product_id: seller_item.seller_product_id,
          name: valid.source.name, brand: valid.source.brand, category: valid.source.category)
        finalize_decision(review_case, seller_item, result_name: "created", product_id: saved.product_id,
          reason: "Explicit creation after review; reassigned from product ##{association.product_id}")
        result(:created, "New product ##{saved.product_id} created and seller ID reassigned.")
      end
      private_class_method :persist_reassigned_creation

      sig { params(review_case_id: Integer, candidate_id: Integer, evidence_revision: Integer).returns(Result) }
      def self.keep_existing(review_case_id:, candidate_id:, evidence_revision:)
        resolve_listing_conflict(review_case_id: review_case_id, candidate_id: candidate_id,
          evidence_revision: evidence_revision, choice: :keep)
      end

      sig { params(review_case_id: Integer, candidate_id: Integer, evidence_revision: Integer).returns(Result) }
      def self.replace_existing(review_case_id:, candidate_id:, evidence_revision:)
        resolve_listing_conflict(review_case_id: review_case_id, candidate_id: candidate_id,
          evidence_revision: evidence_revision, choice: :replace)
      end

      sig do
        params(review_case_id: Integer, candidate_id: Integer, evidence_revision: Integer,
          choice: Symbol).returns(Result)
      end
      def self.resolve_listing_conflict(review_case_id:, candidate_id:, evidence_revision:, choice:)
        other_id = conflicting_seller_item_id(review_case_id, candidate_id)
        with_locked_case(review_case_id, additional_seller_item_id: other_id) do |review_case, seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          match = ProductMatcher.call(valid: current_validation(review_case))
          refresh = refresh_if_changed(review_case, match)
          next refresh if refresh
          decide_current_listing(review_case, seller_item, candidate_id, match, choice)
        end
      rescue Catalog::Public::Writes::ConflictError => error
        catalog_conflict_result(review_case_id, error)
      end
      private_class_method :resolve_listing_conflict

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem, candidate_id: Integer,
          match: ProductMatcher::Result, choice: Symbol).returns(Result)
      end
      def self.decide_current_listing(review_case, seller_item, candidate_id, match, choice)
        candidate = actionable_candidate(review_case, candidate_id)
        return invalid_candidate unless candidate

        conflict = candidate.conflicting_association
        return unsupported_conflict unless conflict.is_a?(Hash) &&
          conflict["seller_product_id"] != seller_item.seller_product_id
        other_association = locked_conflicting_association(conflict, match.seller_item_association)
        return stale_association(review_case) unless other_association

        other_item = Models::SellerItem.find_by(seller_name: seller_item.seller_name,
          seller_product_id: other_association.seller_product_id)
        return stale_association(review_case) unless current_other_item?(other_item, other_association)
        return keep_listing(review_case, seller_item, other_association, match) if choice == :keep

        replace_listing(review_case, seller_item, other_item, other_association, match)
      end
      private_class_method :decide_current_listing

      sig do
        params(other_item: T.nilable(Models::SellerItem),
          other_association: Catalog::Models::SellerProduct).returns(T::Boolean)
      end
      def self.current_other_item?(other_item, other_association)
        other_item.nil? || other_item.product_id == other_association.product_id
      end
      private_class_method :current_other_item?

      sig do
        params(conflict: T::Hash[String, Object], incoming: T.nilable(ProductMatcher::Association))
          .returns(T::Boolean)
      end
      def self.lock_conflict_associations(conflict, incoming)
        snapshots = T.let([ conflict ], T::Array[T.any(ProductMatcher::Association, T::Hash[String, Object])])
        snapshots << incoming if incoming
        snapshots.sort_by! { |snapshot| snapshot.is_a?(Hash) ? T.cast(snapshot.fetch("id"), Integer) : snapshot.id }
        snapshots.all? { |snapshot| locked_current_association(snapshot) }
      end
      private_class_method :lock_conflict_associations

      sig do
        params(conflict: T::Hash[String, Object], incoming: T.nilable(ProductMatcher::Association))
          .returns(T.nilable(Catalog::Models::SellerProduct))
      end
      def self.locked_conflicting_association(conflict, incoming)
        return unless lock_conflict_associations(conflict, incoming)

        locked_current_association(conflict)
      end
      private_class_method :locked_conflicting_association

      sig { params(review_case_id: Integer, error: Catalog::Public::Writes::ConflictError).returns(Result) }
      def self.catalog_conflict_result(review_case_id, error)
        with_locked_case(review_case_id) do |review_case, _seller_item|
          match = ProductMatcher.call(valid: current_validation(review_case))
          refresh_if_changed(review_case, match) ||
            result(:conflict, "Catalog association changed: #{error.message}. Review the case again.")
        end
      end
      private_class_method :catalog_conflict_result

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          other_association: Catalog::Models::SellerProduct, match: ProductMatcher::Result).returns(Result)
      end
      def self.keep_listing(review_case, seller_item, other_association, match)
        if (incoming = match.seller_item_association)
          current = locked_current_association(incoming)
          return stale_association(review_case) unless current
          Catalog::Public::Writes.retire_listing(association_id: current.id,
            expected_product_id: current.product_id, expected_seller_product_id: seller_item.seller_product_id)
        end
        finalize_decision(review_case, seller_item, result_name: "kept_existing",
          product_id: other_association.product_id,
          reason: "Kept seller ID #{other_association.seller_product_id}; declined #{seller_item.seller_product_id}",
          declined_seller_item_id: seller_item.id)
        result(:kept_existing, "Kept seller ID #{other_association.seller_product_id}; incoming ID declined.")
      end
      private_class_method :keep_listing

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          other_item: T.nilable(Models::SellerItem), other_association: Catalog::Models::SellerProduct,
          match: ProductMatcher::Result).returns(Result)
      end
      def self.replace_listing(review_case, seller_item, other_item, other_association, match)
        saved = write_replacement_association(seller_item, other_association, match)
        return stale_association(review_case) unless saved

        other_item&.active_case&.update!(status: "superseded")
        other_item&.update!(resolution: "displaced", product_id: nil)
        finalize_decision(review_case, seller_item, result_name: "linked", product_id: saved.product_id,
          reason: "Replaced seller ID #{other_association.seller_product_id} with #{seller_item.seller_product_id}",
          displaced_seller_item_id: other_item&.id)
        result(:replaced, "Seller ID #{seller_item.seller_product_id} replaced #{other_association.seller_product_id}.")
      end
      private_class_method :replace_listing

      sig do
        params(seller_item: Models::SellerItem, other_association: Catalog::Models::SellerProduct,
          match: ProductMatcher::Result).returns(T.nilable(Catalog::Models::SellerProduct))
      end
      def self.write_replacement_association(seller_item, other_association, match)
        incoming = match.seller_item_association
        return Catalog::Public::Writes.reassign(association_id: other_association.id,
          product_id: other_association.product_id,
          seller_product_id: seller_item.seller_product_id) unless incoming

        current = locked_current_association(incoming)
        return unless current

        Catalog::Public::Writes.replace_listing(survivor_association_id: current.id,
          displaced_association_id: other_association.id,
          expected_survivor_product_id: current.product_id,
          expected_displaced_product_id: other_association.product_id,
          expected_survivor_seller_product_id: seller_item.seller_product_id,
          expected_displaced_seller_product_id: other_association.seller_product_id)
      end
      private_class_method :write_replacement_association

      sig { params(review_case_id: Integer, evidence_revision: Integer).returns(Result) }
      def self.create(review_case_id:, evidence_revision:)
        with_locked_case(review_case_id) do |review_case, seller_item|
          next stale_revision unless review_case.evidence_revision == evidence_revision

          valid = current_validation(review_case)
          match = ProductMatcher.call(valid: valid)
          refresh = refresh_if_changed(review_case, match)
          next refresh if refresh

          next creation_blocked(review_case) unless creation_state(review_case: review_case) == :ready

          persist_creation(review_case, seller_item, valid)
        end
      rescue Catalog::Public::Writes::ConflictError => error
        result(:conflict, "Catalog association changed: #{error.message}. Review the case again.")
      end

      sig { params(review_case: Models::ReviewCase).returns(Result) }
      def self.creation_blocked(review_case)
        case creation_state(review_case: review_case)
        when :incomplete
          result(:invalid, "Complete Brand and Category before creating a product.")
        when :association_conflict
          result(:conflict, "This seller item has an association requiring explicit reassignment.")
        when :candidates
          result(:invalid, "Review or reject every remaining credible candidate before creating a product.")
        else
          result(:not_actionable, "This case is no longer ready for creation.")
        end
      end
      private_class_method :creation_blocked

      sig { params(review_case: Models::ReviewCase, seller_item: Models::SellerItem).returns(T::Boolean) }
      def self.active_pending_case?(review_case, seller_item)
        seller_item.resolution == "pending" && seller_item.active_case&.id == review_case.id
      end
      private_class_method :active_pending_case?

      sig { params(review_case: Models::ReviewCase).returns(T::Boolean) }
      def self.remaining_candidates?(review_case)
        rejected_ids = review_case.review_candidates.joins(:review_rejection).select(:product_id)
        review_case.review_candidates.where(evidence_revision: review_case.evidence_revision)
          .where.not(product_id: rejected_ids).exists?
      end
      private_class_method :remaining_candidates?

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem,
          valid: RowValidator::Valid).returns(Result)
      end
      def self.persist_creation(review_case, seller_item, valid)
        association = Catalog::Public::Writes.create_with_association(name: valid.source.name,
          brand: valid.source.brand, category: valid.source.category,
          seller_name: seller_item.seller_name, seller_product_id: seller_item.seller_product_id)
        Models::ReviewDecision.create!(review_case: review_case, reviewer: Reviewer.name,
          decided_at: Time.current, result: "created", product_id: association.product_id,
          reason: "Explicit creation after review of catalog candidates")
        seller_item.update!(resolution: "created", product_id: association.product_id)
        review_case.update!(status: "resolved")
        result(:created, "Product ##{association.product_id} created and linked after review.")
      end
      private_class_method :persist_creation

      sig do
        params(review_case: Models::ReviewCase, seller_item: Models::SellerItem, result_name: String,
          product_id: Integer, reason: String, displaced_seller_item_id: T.nilable(Integer),
          declined_seller_item_id: T.nilable(Integer)).void
      end
      def self.finalize_decision(review_case, seller_item, result_name:, product_id:, reason:,
        displaced_seller_item_id: nil, declined_seller_item_id: nil)
        Models::ReviewDecision.create!(review_case: review_case, reviewer: Reviewer.name,
          decided_at: Time.current, result: result_name, product_id: product_id, reason: reason,
          displaced_seller_item_id: displaced_seller_item_id,
          declined_seller_item_id: declined_seller_item_id)
        if result_name == "kept_existing"
          seller_item.update!(resolution: "declined", product_id: nil)
        else
          seller_item.update!(resolution: result_name, product_id: product_id)
        end
        review_case.update!(status: "resolved")
      end
      private_class_method :finalize_decision

      sig { params(review_case: Models::ReviewCase, seller_item: Models::SellerItem).returns(T::Boolean) }
      def self.existing_item_conflict?(review_case, seller_item)
        conflict = review_case.conflicting_association
        conflict.is_a?(Hash) && conflict["seller_product_id"] == seller_item.seller_product_id
      end
      private_class_method :existing_item_conflict?

      sig do
        params(review_case_id: Integer, additional_seller_item_id: T.nilable(Integer),
          block: T.proc.params(review_case: Models::ReviewCase,
            seller_item: Models::SellerItem).returns(Result)).returns(Result)
      end
      def self.with_locked_case(review_case_id, additional_seller_item_id: nil, &block)
        seller_item = Models::SellerItem.find(Models::ReviewCase.find(review_case_id).seller_item_id)
        Models::SellerItem.transaction do
          lock_seller_items(seller_item.id, additional_seller_item_id)
          seller_item.reload
          review_case = Models::ReviewCase.lock.find(review_case_id)
          if !review_case.actionable? || seller_item.resolution != "pending" ||
              seller_item.active_case&.id != review_case.id
            next result(:not_actionable, "This case is no longer pending. No action was saved.")
          end

          block.call(review_case, seller_item)
        end
      end
      private_class_method :with_locked_case

      sig { params(seller_item_id: Integer, additional_seller_item_id: T.nilable(Integer)).void }
      def self.lock_seller_items(seller_item_id, additional_seller_item_id)
        ids = [ seller_item_id, additional_seller_item_id ].compact.uniq.sort
        Models::SellerItem.where(id: ids).order(:id).lock.load
      end
      private_class_method :lock_seller_items

      sig { params(review_case_id: Integer, candidate_id: Integer).returns(T.nilable(Integer)) }
      def self.conflicting_seller_item_id(review_case_id, candidate_id)
        candidate = Models::ReviewCandidate.find_by(id: candidate_id, review_case_id: review_case_id)
        conflict = candidate&.conflicting_association
        return unless conflict.is_a?(Hash)

        Models::SellerItem.find_by(seller_name: conflict["seller_name"],
          seller_product_id: conflict["seller_product_id"])&.id
      end
      private_class_method :conflicting_seller_item_id

      sig do
        params(snapshot: T.any(ProductMatcher::Association, T::Hash[String, Object]))
          .returns(T.nilable(Catalog::Models::SellerProduct))
      end
      def self.locked_current_association(snapshot)
        expected = snapshot.is_a?(Hash) ? snapshot : T.must(association_hash(snapshot))
        association = Catalog::Models::SellerProduct.lock.find_by(id: expected["id"])
        return unless association && association_hash_record(association) == expected

        association
      end
      private_class_method :locked_current_association

      sig { params(association: Catalog::Models::SellerProduct).returns(T::Hash[String, Object]) }
      def self.association_hash_record(association)
        { "id" => association.id, "product_id" => association.product_id,
          "seller_name" => association.seller_name, "seller_product_id" => association.seller_product_id }
      end
      private_class_method :association_hash_record

      sig { params(review_case: Models::ReviewCase).returns(Result) }
      def self.stale_association(review_case)
        match = ProductMatcher.call(valid: current_validation(review_case))
        refresh_if_changed(review_case, match)
        result(:stale, "Catalog association changed. Review the refreshed evidence before acting.")
      end
      private_class_method :stale_association

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
        { "rank" => rank, "product_id" => candidate.product_id,
          "score" => stored_score(candidate.score),
          "original" => { "name" => candidate.original.name, "brand" => candidate.original.brand,
            "category" => candidate.original.category },
          "comparison" => { "name" => candidate.comparison.name, "brand" => candidate.comparison.brand,
            "category" => candidate.comparison.category },
          "differing_fields" => candidate.differing_fields.map(&:to_s),
          "conflicting_association" => association_hash(candidate.seller_product_conflict) }
      end
      private_class_method :match_snapshot

      sig { params(score: Float).returns(BigDecimal) }
      def self.stored_score(score)
        BigDecimal(score.to_s).round(7)
      end
      private_class_method :stored_score

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
