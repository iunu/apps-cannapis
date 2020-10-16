module MetrcService
  module Plant
    class Base < MetrcService::Base
      private

      def completions_by_action_type(action_type)
        get_child_completions(@completion_id, filter: { action_type: action_type })
      end
    end
  end
end
