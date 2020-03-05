module MetrcService
  module SalesOrder
    class Start < MetrcService::Package::Base
      def call
        # do nothing?

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_sales_order_batch)
      end
    end
  end
end
