module MetrcService
  class Batch
    def call(task)
      @logger.info "[METRC_BATCH] Started: batch ID #{@batch_id}"

      begin
        @integration.account.refresh_token_if_needed
        batch = get_batch

        unless batch.crop == MetrcService::CROP
          @logger.warn "[METRC_BATCH] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}"
          task.delete
          return
        end

        completion_ids = batch.objects['completions'].keys
        completions = []
        performed_transactions = Transaction.succeed.where(batch_id: batch.id,
                                                           completion_id: completion_ids,
                                                           integration: @integration)&.pluck(:completion_id)

        # Filter the completions we curently support
        batch.objects['completions'].select do |id|
          completion = batch.objects['completions'][id]
          completions << completion.attributes if V1::WebhookController::COMPLETION_TYPES.include?(completion.action_type) && !performed_transactions.include?(id.to_i)
        end

        unless completions.size.positive?
          @logger.warn "[METRC_BATCH] Completions where already performed. Batch ID #{@batch_id}"
          task.delete
          return
        end

        Parallel.each(completions) do |completion|
          module_for_completion = "MetrcService::#{completion.action_type}".constantize
          module_for_completion.new(completion.attributes, @integration, batch).call
        end
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[METRC_BATCH] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        task.delete
      end
    end
  end
end
