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
      transactions = completions.each_with_object([]) do |completion, arr|
        ctx = {
          id: completion.id,
          type: :completions,
          attributes: completion.attributes,
          relationships: @relationships
        }.with_indifferent_access

        arr << MetrcService.perform_action(ctx, @integration, @task)
        # halt if the last action failed
        break arr unless arr.last&.success? || arr.last&.skipped?
      end

      # a stub tranasction to represent the state of the batched transactions
      result = Transaction.new(success: transactions.all? { |t| t.success? || t.skipped? })
      @task.delete if result.success?

      result
    end

    def batch
      @batch ||= get_batch
    end

    def validate_batch!
      super
    rescue StandardError
      @task.delete
      raise
    end

    def validate_completions!(completions)
      return completions if completions.size.positive?

      @task.delete
      raise TransactionAlreadyExecuted, 'batch already processed'
    end

    def completions
      @completions ||= filter_and_validate_completions
    end

    def filter_and_validate_completions
      filtered_completions = batch_completions.select do |c|
        completion_supported?(c) &&
          completed_after_integration_activation?(c) &&
          !performed_transactions.include?(c.id) &&
          !skipped_transactions.include?(c.id)
      end
      sorted_completions = filtered_completions.sort_by { |c| [c.start_time, c.id] }

      validate_completions!(sorted_completions)
    end

    # Completion type is supported (COMPLETION_TYPES)
    #  - If completion type is generate or consume the resource unit type must also be supported.
    def completion_supported?(completion)
      return false unless V1::WebhookController::COMPLETION_TYPES.include?(completion.action_type)

      %w[generate consume].include?(completion.action_type) ? resource_unit_type_supported?(completion) : true
    end

    def resource_unit_type_supported?(completion)
      resource_unit = artemis.get_resource_unit(completion.options&.dig('resource_unit_id'))
      resource_unit&.name&.downcase&.include?('wet weight') ||
        resource_unit&.name&.downcase&.include?('waste')
    end

    # check that the completion was created after the integration was activated.
    # these completions should have already been reported to metrc
    def completed_after_integration_activation?(completion)
      if completion.created_at
        completion.created_at > @integration.activated_at
      else
        completion.start_time > @integration.activated_at
      end
    end

    def performed_transactions
      Transaction.succeed.where(batch_id: batch.id,
                                completion_id: batch_completions.map(&:id),
                                integration: @integration)&.pluck(:completion_id)
    end

    def skipped_transactions
      Transaction.skipped.where(batch_id: batch.id,
                                completion_id: batch_completions.map(&:id),
                                integration: @integration)&.pluck(:completion_id)
    end
  end
end
