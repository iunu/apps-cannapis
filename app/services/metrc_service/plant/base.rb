module MetrcService
  module Plant
    class Base < MetrcService::Base
      private

      def handle_resources
        return unless can_sync_harvests?

        handle_generated_resources
        handle_processed_resources
        handle_consumed_resources
      end

      def handle_generated_resources
        return if completions_by_action_type('generate').empty?

        Resource::WetWeight.call(@ctx, @integration, @batch)
        Resource::WetWaste.call(@ctx, @integration, @batch)
      end

      def handle_processed_resources; end

      def handle_consumed_resources; end

      def completions_by_action_type(action_type)
        get_child_completions(@completion_id, filter: { action_type: action_type })
      end
    end
  end
end
