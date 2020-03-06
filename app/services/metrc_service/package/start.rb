module MetrcService
  module Package
    class Start < MetrcService::Package::Base
      def call
        # do nothing?

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_package_batch)
      end
    end
  end
end
