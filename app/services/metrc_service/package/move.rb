module MetrcService
  module Package
    class Move < MetrcService::Package::Base
      def call
        # do nothing?

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:move_package_batch)
      end
    end
  end
end
