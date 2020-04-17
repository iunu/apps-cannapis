module MetrcService
  module Plant
    class Base < MetrcService::Base
      private

      def handle_resources
        handle_generated_resources
        handle_processed_resources
      end

      def handle_generated_resources
        Resource::Waste.call(@ctx, @integration, @batch)
      end

      def handle_processed_resources; end
    end
  end
end
