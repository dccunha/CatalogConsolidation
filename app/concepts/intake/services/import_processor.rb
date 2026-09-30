# typed: true

module Intake
  module Services
    # Internal importer; web upload and reviewer commands are later tasks.
    class ImportProcessor
      extend T::Sig

      OUTCOMES = %w[linked created already_imported pending_review failed].freeze

      class FileError < StandardError; end

      class Row < T::Struct
        const :position, Integer
        const :seller_name, T.nilable(String)
        const :seller_product_id, T.nilable(String)
        const :outcome, String
        const :reason, String
        const :product_id, T.nilable(Integer)
        const :review_case_id, T.nilable(Integer)
      end

      class Result < T::Struct
        const :batch_id, Integer
        const :input_count, Integer
        const :totals, T::Hash[String, Integer]
        const :rows, T::Array[Row]
      end

      sig { params(json: String, source_name: String).returns(Result) }
      def self.call(json:, source_name:)
        elements = parse_array(json)
        batch = Models::Batch.create!(source_name: source_name, input_count: elements.length, created_at: Time.current)
        elements.each_with_index do |element, index|
          process_element(batch: batch, element: element, position: index + 1)
        end
        report(batch)
      end

      sig { params(batch_id: Integer).returns(Result) }
      def self.fetch(batch_id:)
        report(Models::Batch.find(batch_id))
      end

      sig { params(json: String).returns(T::Array[Object]) }
      def self.parse_array(json)
        parsed = JSON.parse(json)
        raise FileError, "Import file must contain a JSON array" unless parsed.is_a?(Array)

        parsed
      rescue JSON::ParserError => error
        raise FileError, "Import file contains malformed JSON: #{error.message}"
      end
      private_class_method :parse_array

      sig { params(batch: Models::Batch, element: Object, position: Integer).void }
      def self.process_element(batch:, element:, position:)
        input_json = JSON.generate(element)
        validation = RowValidator.call(element)
        if validation.is_a?(RowValidator::Invalid)
          save_invalid(batch: batch, validation: validation, input_json: input_json, position: position)
          return
        end

        begin
          Models::RowResult.transaction do
            process_valid(batch: batch, valid: validation, element: element,
              input_json: input_json, position: position)
          end
        rescue StandardError => error
          save_failed(batch: batch, valid: validation, input_json: input_json,
            position: position, error: error)
        end
      end
      private_class_method :process_element

      sig do
        params(batch: Models::Batch, validation: RowValidator::Invalid,
          input_json: String, position: Integer).void
      end
      def self.save_invalid(batch:, validation:, input_json:, position:)
        errors = validation.errors.map { |error| { field: error.field, code: error.code.to_s } }
        key = valid_key(validation.input)
        Models::RowResult.create!(batch: batch, source_position: position, input_json: input_json,
          seller_name: key&.first, seller_product_id: key&.last, outcome: "failed",
          reason: validation_reason(validation.errors), validation_errors: errors)
      end
      private_class_method :save_invalid

      sig { params(input: Object).returns(T.nilable([ String, String ])) }
      def self.valid_key(input)
        return unless input.is_a?(Hash)

        seller_name = input["SellerName"]
        seller_product_id = input["Id"]
        return unless seller_name.is_a?(String) && seller_product_id.is_a?(String)
        return if [ seller_name, seller_product_id ].any? { |value| value.gsub(/\p{Space}+/, " ").strip.empty? }

        [ seller_name, seller_product_id ]
      end
      private_class_method :valid_key

      sig { params(errors: T::Array[RowValidator::Error]).returns(String) }
      def self.validation_reason(errors)
        errors.map do |error|
          if error.code == :not_an_object
            "Row must be a JSON object"
          else
            "#{error.field} #{error.code == :required ? 'is required' : 'must be a string'}"
          end
        end.join("; ")
      end
      private_class_method :validation_reason

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, element: Object,
          input_json: String, position: Integer).void
      end
      def self.process_valid(batch:, valid:, element:, input_json:, position:)
        lock_seller_key(valid)
        existing = Models::SellerItem.lock.find_by(seller_name: valid.source.seller_name,
          seller_product_id: valid.source.seller_product_id)
        if existing
          process_existing(batch: batch, valid: valid, element: element, input_json: input_json,
            position: position, seller_item: existing)
          return
        end

        match = ProductMatcher.call(valid: valid)
        case match.recommendation
        when :link
          link_row(batch: batch, valid: valid, match: match, element: element,
            input_json: input_json, position: position)
        when :create
          create_row(batch: batch, valid: valid, element: element,
            input_json: input_json, position: position)
        else
          review_row(batch: batch, valid: valid, match: match, element: element,
            input_json: input_json, position: position)
        end
      end
      private_class_method :process_valid

      sig { params(valid: RowValidator::Valid).void }
      def self.lock_seller_key(valid)
        # The digest yields an integer only; no seller text is interpolated into SQL.
        key = Digest::SHA256.hexdigest(JSON.generate(
          [ valid.source.seller_name, valid.source.seller_product_id ])).first(15).to_i(16)
        Models::SellerItem.connection.execute("SELECT pg_advisory_xact_lock(#{key})")
      end
      private_class_method :lock_seller_key

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, element: Object, input_json: String,
          position: Integer, seller_item: Models::SellerItem).void
      end
      def self.process_existing(batch:, valid:, element:, input_json:, position:, seller_item:)
        if seller_item.active_source_comparison == comparison_hash(valid)
          repeat_row(batch: batch, valid: valid, input_json: input_json,
            position: position, seller_item: seller_item)
        else
          changed_row(batch: batch, valid: valid, element: element, input_json: input_json,
            position: position, seller_item: seller_item)
        end
      end
      private_class_method :process_existing

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, input_json: String,
          position: Integer, seller_item: Models::SellerItem).void
      end
      def self.repeat_row(batch:, valid:, input_json:, position:, seller_item:)
        review_case = seller_item.active_case
        if seller_item.resolution == "pending"
          raise "Pending seller item #{seller_item.id} has no pending case" unless review_case&.actionable?

          save_row(batch: batch, valid: valid, input_json: input_json, position: position,
            outcome: "pending_review", reason: "Pending review in case #{review_case.id}: #{review_case.reason}",
            review_case_id: review_case.id)
          return
        end

        decision = retained_decision(seller_item, review_case)
        save_row(batch: batch, valid: valid, input_json: input_json, position: position,
          outcome: "already_imported", reason: retained_reason(seller_item, decision),
          product_id: seller_item.product_id, review_case_id: decision&.review_case_id)
      end
      private_class_method :repeat_row

      sig do
        params(seller_item: Models::SellerItem, review_case: T.nilable(Models::ReviewCase))
          .returns(T.nilable(Models::ReviewDecision))
      end
      def self.retained_decision(seller_item, review_case)
        if seller_item.resolution == "displaced"
          return Models::ReviewDecision.where(displaced_seller_item_id: seller_item.id).order(:id).last
        end

        review_case.review_decision if review_case && review_case.status == "resolved"
      end
      private_class_method :retained_decision

      sig { params(seller_item: Models::SellerItem, decision: T.nilable(Models::ReviewDecision)).returns(String) }
      def self.retained_reason(seller_item, decision)
        return "Already imported: #{seller_item.resolution} to catalog product #{seller_item.product_id}" unless decision

        detail = decision.reason.present? ? ": #{decision.reason}" : ""
        "Already imported: retained #{decision.result} decision #{decision.id}#{detail}; " \
          "#{seller_item.resolution}#{seller_item.product_id ? " to catalog product #{seller_item.product_id}" : ' without association'}"
      end
      private_class_method :retained_reason

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, element: Object, input_json: String,
          position: Integer, seller_item: Models::SellerItem).void
      end
      def self.changed_row(batch:, valid:, element:, input_json:, position:, seller_item:)
        active_case = seller_item.active_case
        active_case&.update!(status: "superseded")
        seller_item.update!(active_source_input: element, active_source_comparison: comparison_hash(valid),
          resolution: "pending")
        match = ProductMatcher.call(valid: valid)
        reason = "changed source identity"
        reasons = match.reasons.map { |item| item.to_s.tr("_", " ") }
        reason = "#{reason}; #{reasons.join('; ')}" if reasons.any?
        review_case = Models::ReviewCase.create!(seller_item: seller_item, batch: batch,
          source_position: position, status: "pending", reason: reason,
          source_input: element, source_comparison: comparison_hash(valid),
          evidence_revision: 1, conflicting_association: conflict_hash(match))
        save_candidates(review_case: review_case, candidates: match.candidates)
        save_row(batch: batch, valid: valid, input_json: input_json, position: position,
          outcome: "pending_review", reason: "Pending review: #{reason}", review_case_id: review_case.id)
      end
      private_class_method :changed_row

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, match: ProductMatcher::Result,
          element: Object, input_json: String, position: Integer).void
      end
      def self.link_row(batch:, valid:, match:, element:, input_json:, position:)
        product_id = match.product_id
        raise ArgumentError, "Link recommendation has no product" unless product_id

        association = Catalog::Public::Writes.link(product_id: product_id,
          seller_name: valid.source.seller_name, seller_product_id: valid.source.seller_product_id)
        save_seller_item(valid: valid, element: element, resolution: "linked", product_id: association.product_id)
        save_row(batch: batch, valid: valid, input_json: input_json, position: position,
          outcome: "linked", reason: "Linked to exact catalog product #{association.product_id}",
          product_id: association.product_id)
      end
      private_class_method :link_row

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, element: Object,
          input_json: String, position: Integer).void
      end
      def self.create_row(batch:, valid:, element:, input_json:, position:)
        association = Catalog::Public::Writes.create_with_association(
          name: valid.source.name, brand: valid.source.brand, category: valid.source.category,
          seller_name: valid.source.seller_name, seller_product_id: valid.source.seller_product_id)
        save_seller_item(valid: valid, element: element, resolution: "created", product_id: association.product_id)
        save_row(batch: batch, valid: valid, input_json: input_json, position: position,
          outcome: "created", reason: "Created catalog product #{association.product_id}",
          product_id: association.product_id)
      end
      private_class_method :create_row

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, match: ProductMatcher::Result,
          element: Object, input_json: String, position: Integer).void
      end
      def self.review_row(batch:, valid:, match:, element:, input_json:, position:)
        seller_item = save_seller_item(valid: valid, element: element, resolution: "pending", product_id: nil)
        reason = match.reasons.map { |item| item.to_s.tr("_", " ") }.join("; ")
        review_case = Models::ReviewCase.create!(seller_item: seller_item, batch: batch,
          source_position: position, status: "pending", reason: reason,
          source_input: element, source_comparison: comparison_hash(valid),
          evidence_revision: 1, conflicting_association: conflict_hash(match))
        save_candidates(review_case: review_case, candidates: match.candidates)
        save_row(batch: batch, valid: valid, input_json: input_json, position: position,
          outcome: "pending_review", reason: "Pending review: #{reason}", review_case_id: review_case.id)
      end
      private_class_method :review_row

      sig do
        params(valid: RowValidator::Valid, element: Object, resolution: String,
          product_id: T.nilable(Integer)).returns(Models::SellerItem)
      end
      def self.save_seller_item(valid:, element:, resolution:, product_id:)
        Models::SellerItem.create!(seller_name: valid.source.seller_name,
          seller_product_id: valid.source.seller_product_id, active_source_input: element,
          active_source_comparison: comparison_hash(valid), resolution: resolution, product_id: product_id)
      end
      private_class_method :save_seller_item

      sig { params(valid: RowValidator::Valid).returns(T::Hash[String, T.nilable(String)]) }
      def self.comparison_hash(valid)
        { "name" => valid.comparison.name, "brand" => valid.comparison.brand,
          "category" => valid.comparison.category }
      end
      private_class_method :comparison_hash

      sig { params(match: ProductMatcher::Result).returns(T.nilable(T::Hash[String, Object])) }
      def self.conflict_hash(match)
        association = match.seller_item_association || match.candidates.filter_map(&:seller_product_conflict).first
        return unless association

        association_hash(association)
      end
      private_class_method :conflict_hash

      sig { params(association: ProductMatcher::Association).returns(T::Hash[String, Object]) }
      def self.association_hash(association)
        { "id" => association.id, "product_id" => association.product_id,
          "seller_name" => association.seller_name, "seller_product_id" => association.seller_product_id }
      end
      private_class_method :association_hash

      sig { params(review_case: Models::ReviewCase, candidates: T::Array[ProductMatcher::Candidate]).void }
      def self.save_candidates(review_case:, candidates:)
        candidates.each_with_index do |candidate, index|
          save_candidate(review_case: review_case, candidate: candidate, rank: index + 1)
        end
      end
      private_class_method :save_candidates

      sig { params(review_case: Models::ReviewCase, candidate: ProductMatcher::Candidate, rank: Integer).void }
      def self.save_candidate(review_case:, candidate:, rank:)
        Models::ReviewCandidate.create!(review_case: review_case, product_id: candidate.product_id,
          evidence_revision: 1, rank: rank, score: candidate.score,
          original: { "name" => candidate.original.name, "brand" => candidate.original.brand,
            "category" => candidate.original.category },
          comparison: { "name" => candidate.comparison.name, "brand" => candidate.comparison.brand,
            "category" => candidate.comparison.category },
          differing_fields: candidate.differing_fields.map(&:to_s),
          conflicting_association: candidate_conflict_hash(candidate))
      end
      private_class_method :save_candidate

      sig { params(candidate: ProductMatcher::Candidate).returns(T.nilable(T::Hash[String, Object])) }
      def self.candidate_conflict_hash(candidate)
        association = candidate.seller_product_conflict
        association_hash(association) if association
      end
      private_class_method :candidate_conflict_hash

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, input_json: String, position: Integer,
          outcome: String, reason: String, product_id: T.nilable(Integer),
          review_case_id: T.nilable(Integer)).void
      end
      def self.save_row(batch:, valid:, input_json:, position:, outcome:, reason:, product_id: nil, review_case_id: nil)
        Models::RowResult.create!(batch: batch, source_position: position, input_json: input_json,
          seller_name: valid.source.seller_name, seller_product_id: valid.source.seller_product_id,
          outcome: outcome, reason: reason, product_id: product_id, review_case_id: review_case_id)
      end
      private_class_method :save_row

      sig do
        params(batch: Models::Batch, valid: RowValidator::Valid, input_json: String,
          position: Integer, error: StandardError).void
      end
      def self.save_failed(batch:, valid:, input_json:, position:, error:)
        save_row(batch: batch, valid: valid, input_json: input_json, position: position,
          outcome: "failed", reason: "Row failed: #{error.class}: #{error.message}")
      end
      private_class_method :save_failed

      sig { params(batch: Models::Batch).returns(Result) }
      def self.report(batch)
        records = batch.row_results.order(:source_position).to_a
        positions = records.map(&:source_position)
        raise "Incomplete import batch #{batch.id}" unless positions == (1..batch.input_count).to_a

        Result.new(batch_id: batch.id, input_count: batch.input_count,
          totals: report_totals(batch), rows: records.map { |record| report_row(record) })
      end
      private_class_method :report

      sig { params(batch: Models::Batch).returns(T::Hash[String, Integer]) }
      def self.report_totals(batch)
        counts = batch.row_results.group(:outcome).count
        OUTCOMES.index_with { |outcome| counts.fetch(outcome, 0) }
      end
      private_class_method :report_totals

      sig { params(record: Models::RowResult).returns(Row) }
      def self.report_row(record)
        Row.new(position: record.source_position, seller_name: record.seller_name,
          seller_product_id: record.seller_product_id, outcome: record.outcome, reason: record.reason,
          product_id: record.product_id, review_case_id: record.review_case_id)
      end
      private_class_method :report_row
    end
  end
end
