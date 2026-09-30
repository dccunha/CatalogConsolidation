# typed: true

module Intake
  module Controllers
    class BatchesController < BaseController
      def index
        @batches = Models::Batch.order(id: :desc)
      end

      def show
        @batch = Models::Batch.find(params[:id])
        @report = Services::ImportProcessor.fetch(batch_id: @batch.id)
        @rows = @batch.row_results.order(:source_position)
      end
    end
  end
end
