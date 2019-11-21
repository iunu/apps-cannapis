module MetrcService
  class Batch < MetrcService::Base
    def call(task)
      @logger.info "[METRC_BATCH] Started: batch ID #{@batch_id}"

      begin
        @integration.account.refresh_token_if_needed
        batch = get_batch 'zone,barcodes,harvests,completions,custom_data,seeding_unit,harvest_unit,sub_zone,items,discard'

        unless batch.crop == MetrcService::CROP
          @logger.warn "[METRC_BATCH] Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}"
          task.delete
          return
        end

        actions = batch.client.objects['completions']
        completion_ids = actions.keys
        completions = []
        performed_transactions = Transaction.succeed.where(batch_id: batch.id,
                                                           completion_id: completion_ids,
                                                           integration: @integration)&.pluck(:completion_id)

        # Filter the completions we curently support
        actions.select do |id|
          completion = actions[id]
          completions << completion if V1::WebhookController::COMPLETION_TYPES.include?(completion.action_type) && !performed_transactions.include?(id)
        end

        unless completions.size.positive?
          @logger.warn "[METRC_BATCH] Completions where already performed. Batch ID #{@batch_id}"
          task.delete
          return
        end

        completions.each do |completion|
          ctx = {
            id: completion.id,
            type: :completions,
            attributes: completion.attributes,
            relationships: @relationships
          }.with_indifferent_access
          module_for_completion = "MetrcService::#{completion.action_type.camelize}".constantize

          module_for_completion.call(ctx, @integration, batch)
        end

        task.delete
        return
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[METRC_BATCH] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      end
    end
  end
end
