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
        @creation_state = Services::ReviewActions.creation_state(review_case: @review_case)
      end

      def approve
        review_result = Services::ReviewActions.approve(review_case_id: params[:id].to_i,
          candidate_id: params[:candidate_id].to_i, evidence_revision: params[:evidence_revision].to_i)
        finish_action(review_result)
      end

      def reject
        unless params[:reason].is_a?(String)
          return invalid_action("Enter a text reason for rejecting this candidate.")
        end

        review_result = Services::ReviewActions.reject(review_case_id: params[:id].to_i,
          candidate_id: params[:candidate_id].to_i, evidence_revision: params[:evidence_revision].to_i,
          reason: params[:reason])
        finish_action(review_result)
      end

      def correct
        name, brand, category = params.values_at(:name, :brand, :category)
        unless name.is_a?(String) && (brand.nil? || brand.is_a?(String)) &&
            (category.nil? || category.is_a?(String))
          return invalid_action("Enter a name and text values for Brand and Category.")
        end

        review_result = Services::ReviewActions.correct(review_case_id: params[:id].to_i,
          evidence_revision: params[:evidence_revision].to_i, name: name, brand: brand, category: category)
        finish_action(review_result)
      end

      def create_product
        review_result = Services::ReviewActions.create(review_case_id: params[:id].to_i,
          evidence_revision: params[:evidence_revision].to_i)
        finish_action(review_result)
      end

      private

      def load_case_evidence
        @candidates = @review_case.review_candidates.where(evidence_revision: @review_case.evidence_revision)
          .includes(:review_rejection).order(:rank)
        @rows = @review_case.row_results.includes(:batch).order(:created_at, :id)
        @rejected_product_ids = @review_case.review_candidates.joins(:review_rejection).pluck(:product_id).to_set
        latest_correction = @review_case.review_corrections.order(:id).last
        @current_input = latest_correction ? latest_correction.corrected_input : @review_case.source_input
      end

      def finish_action(review_result)
        flash[review_result.success? ? :notice : :alert] = review_result.message
        redirect_to review_case_path(params[:id]), status: :see_other
      end

      def invalid_action(message)
        finish_action(Services::ReviewActions::Result.new(status: :invalid, message: message))
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
