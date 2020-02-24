module MetrcService
  module Package
    class Start < MetrcService::Package::Base
      def call
        # do nothing?

        transaction.success = true
        log("Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}")

        transaction
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_package_batch)
      end
    end
  end
end
