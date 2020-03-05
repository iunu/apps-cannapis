module MetrcService
  module SalesOrder
    class Move < MetrcService::Package::Base
      def call
        # do nothing?

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:move_sales_order_batch)
      end
    end
  end
end
