module Common
  module PlantResourceTriggers
    private

    def handle_resources
      handle_generated_resources
      handle_processed_resources
      handle_consumed_resources
    end

    def handle_generated_resources
      return if completions_by_action_type('generate').empty?

      scope::Resource::WetWeight.call(@ctx, @integration, @batch)
      scope::Resource::WetWaste.call(@ctx, @integration, @batch)
    end

    def handle_processed_resources; end

    def handle_consumed_resources; end

    def completions_by_action_type(action_type)
      get_child_completions(@completion_id, filter: { action_type: action_type })
    end
  end
end
