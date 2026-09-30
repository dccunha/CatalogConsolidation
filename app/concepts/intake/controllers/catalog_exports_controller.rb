# typed: true

module Intake
  module Controllers
    class CatalogExportsController < BaseController
      def show
        @product_count = Catalog::Models::Product.count
        @seller_product_count = Catalog::Models::SellerProduct.count
        @pending_count = Models::ReviewCase.where(status: "pending").count
        @historical_failures = Models::RowResult.where(outcome: "failed").exists?
      end

      def download
        bytes = T.let(nil, T.nilable(String))
        pending_count = 0
        ApplicationRecord.transaction(isolation: :repeatable_read) do
          ApplicationRecord.connection.execute("SET TRANSACTION READ ONLY")
          pending_count = Models::ReviewCase.where(status: "pending").count
          bytes = Catalog::Public::Exports.sqlite_snapshot if pending_count.zero?
        end

        if pending_count.positive?
          @pending_count = pending_count
          return render :blocked, status: :conflict
        end

        send_data T.must(bytes), filename: "catalog-updated.db", type: "application/vnd.sqlite3", disposition: :attachment
      rescue Catalog::Services::SqliteExporter::Error
        render plain: "The catalog download could not be generated. Please try again.", status: :service_unavailable
      end
    end
  end
end
