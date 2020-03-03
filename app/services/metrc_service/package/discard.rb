module MetrcService
  module Package
    class Discard < MetrcService::Package::Base
      def call
        # do nothing?

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:discard_package_batch)
      end
    end
  end
end
