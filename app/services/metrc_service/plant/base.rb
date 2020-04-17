module MetrcService
  module Plant
    class Base < MetrcService::Base
      private

      def handle_resources
        handle_generated_resources
        handle_processed_resources
        handle_consumed_resources
      end

      def handle_generated_resources
        Resource::WetWeight.call(@ctx, @integration, @batch)
        Resource::Waste.call(@ctx, @integration, @batch)
      end

      def handle_processed_resources; end

      def handle_consumed_resources; end
    end
  end
end
