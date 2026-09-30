# typed: true

module Intake
  module Controllers
    class ImportsController < BaseController
      def new
      end

      def create
        upload = params[:file]
        unless upload.respond_to?(:read) && upload.respond_to?(:original_filename)
          @error = "Choose a JSON file to upload."
          render :new, status: :unprocessable_content
          return
        end

        result = Services::ImportProcessor.call(json: upload.read, source_name: upload.original_filename)
        redirect_to batch_path(result.batch_id), notice: "Import completed."
      rescue Services::ImportProcessor::FileError => error
        @error = error.message
        render :new, status: :unprocessable_content
      end
    end
  end
end
