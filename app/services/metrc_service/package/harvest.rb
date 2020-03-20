require 'ostruct'

module MetrcService
  module Package
    class Harvest < MetrcService::Package::Base
      def call
        # finishing packages not yet supported

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_package_batch)
      end
    end
  end
end
