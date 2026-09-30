# typed: true

module Intake
  module Controllers
    class ReviewCasesController < BaseController
      def index
        load_filters
        load_filter_options

        @review_cases = Models::ReviewCase.includes(:seller_item, :batch, :review_decision).order(id: :desc)
        @review_cases = @review_cases.where(status: @status) unless @status == "all"
        @review_cases = filter_by_batch(@review_cases)
        @review_cases = filter_by_seller(@review_cases)
      end

      def show
        @review_case = Models::ReviewCase.includes(:seller_item, :batch, :review_decision).find(params[:id])
        load_case_evidence
        load_history
      end

      private

      def load_case_evidence
        @candidates = @review_case.review_candidates.where(evidence_revision: @review_case.evidence_revision)
          .includes(:review_rejection).order(:rank)
        @rows = @review_case.row_results.includes(:batch).order(:created_at, :id)
      end

      def load_history
        @corrections = @review_case.review_corrections.order(:corrected_at, :id)
        @rejections = Models::ReviewRejection.includes(:review_candidate)
          .where(review_candidate_id: @review_case.review_candidates.select(:id)).order(:rejected_at, :id)
        @history_events = (@corrections.to_a + @rejections.to_a + [ @review_case.review_decision ].compact)
          .sort_by { |event| history_sort_key(event) }
      end

      def load_filters
        @status = params[:status].presence_in(%w[pending resolved superseded all]) || "pending"
        @batch_id = params[:batch_id].to_s
        @seller_name = params[:seller_name].to_s
      end

      def load_filter_options
        @batches = Models::Batch.order(id: :desc).to_a
        @sellers = Models::SellerItem.distinct.order(:seller_name).pluck(:seller_name)
      end

      def filter_by_batch(scope)
        return scope if @batch_id.blank?
        return scope.none unless @batches.any? { |batch| batch.id.to_s == @batch_id }

        scope.where(id: Models::RowResult.where(batch_id: @batch_id).select(:review_case_id))
      end

      def filter_by_seller(scope)
        return scope if @seller_name.blank?

        scope.joins(:seller_item).where(intake_seller_items: { seller_name: @seller_name })
      end

      def history_sort_key(event)
        case event
        when Models::ReviewCorrection then [ event.corrected_at, 0, event.id ]
        when Models::ReviewRejection then [ event.rejected_at, 1, event.id ]
        when Models::ReviewDecision then [ event.decided_at, 2, event.id ]
        end
      end
    end
  end
end
