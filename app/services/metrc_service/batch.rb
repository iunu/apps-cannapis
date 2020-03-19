module MetrcService
  class Batch < MetrcService::Base
    def initialize(ctx, integration, batch = nil, task = nil)
      @task = task
      super(ctx, integration, batch)
    end

    def before
      validate_batch!
    end

    def after; end

    def call
      completions.each do |completion|
        ctx = {
          id: completion.id,
          type: :completions,
          attributes: completion.attributes,
          relationships: @relationships
        }.with_indifferent_access

        MetrcService.perform_action(ctx, @integration, @task)
      end

      @task.delete

      # explicitly return nil
      nil
    end

    def batch
      @batch ||= get_batch 'zone,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone'
    end

    def validate_batch!
      super
    rescue StandardError
      @task.delete
      raise
    end

    def validate_completions!(completions)
      return if completions.size.positive?

      @task.delete
      raise InvalidOperation, "Completions where already performed. Batch ID #{@batch_id}"
    end

    def completions
      @completions ||= filter_and_validate_completions
    end

    def filter_and_validate_completions
      [].tap do |arr|
        # Filter the completions we curently support
        actions.select do |id|
          completion = actions[id]
          arr << completion if completion_supported?(completion) && !performed_transactions.include?(id)
        end

        validate_completions!(arr)
      end
    end

    def completion_supported?(completion)
      V1::WebhookController::COMPLETION_TYPES.include?(completion.action_type)
    end

    def performed_transactions
      Transaction.succeed.where(batch_id: batch.id,
                                completion_id: actions.keys,
                                integration: @integration)&.pluck(:completion_id)
    end

    def actions
      @actions ||= batch.client.objects['completions']
    end
  end
end
