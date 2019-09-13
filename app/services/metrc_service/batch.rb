module MetrcService
  class Batch < ApplicationService
    def initialize(ctx, integration)
      @batch_id      = ctx.dig(:relationships, :batch, :data, :id)
      @facility_id   = ctx.dig(:relationships, :facility, :data, :id)
      @completion_id = ctx[:id]
      @ctx           = ctx
      @integration   = integration
      @logger        = MetrcService.logger
      @client        = MetrcService.client(@integration)
    end

    def start
      @logger.info "[BATCH_START] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = MetrcService.transaction @integration, @batch_id, @completion_id, :start_batch

      if transaction.success
        @logger.error "[BATCH_START] Success: transaction previously performed. #{transaction.inspect}"
        return
      end

      begin
        @integration.account.refresh_token_if_needed
        batch = get_batch

        unless batch.crop == MetrcService::CROP
          @logger.error "[BATCH_START] Failed: Crop is not #{CROP} but #{batch.crop}. batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        payload = build_start_payload(batch)
        @logger.debug "[BATCH_START] Metrc API request. URI #{@client.uri}, payload #{payload}"
        @client.create_plant_batches(@integration.vendor_id, [payload])
        transaction.success = true
        @logger.info "[BATCH_START] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[BATCH_START] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[BATCH_START] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    def discard
      @logger.info "[BATCH_DISCARD] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = MetrcService.transaction @integration, @batch_id, @completion_id, :discard_batch

      if transaction.success
        @logger.error "[BATCH_DISCARD] Success: transaction previously performed. #{transaction.inspect}"
        return
      end

      begin
        @integration.account.refresh_token_if_needed
        batch   = ArtemisApi::Discard.find(@ctx[:relationships][:action_result][:data][:id],
                                           @facility_id,
                                           @integration.account.client,
                                           include: 'batch,barcodes')
        payload = build_discard_payload(batch)
        @logger.debug "[BATCH_DISCARD] Metrc API request. URI #{@client.uri}, payload #{payload}"
        @client.destroy_plant_batches(@integration.vendor_id, [payload])
        transaction.success = true
        @logger.info "[BATCH_DISCARD] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[BATCH_DISCARD] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[BATCH_DISCARD] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    def move
      @logger.info "[BATCH_MOVE] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
      transaction = MetrcService.transaction @integration, @batch_id, @completion_id, :move_batch

      if transaction.success
        @logger.error "[BATCH_MOVE] Success: transaction previously performed. #{transaction.inspect}"
        return
      end

      begin
        @integration.account.refresh_token_if_needed
        batch = get_batch

        unless batch.crop == MetrcService::CROP
          @logger.error "[BATCH_MOVE] Failed: Crop is not #{CROP} but #{batch.crop}. batch ID #{@batch_id}, completion ID #{@completion_id}"
          return
        end

        zone_name      = @ctx.dig(:data, :attributes, :options, :zone_name)
        payload_method = 'move'
        client_method  = 'move_plant_batches'

        if zone_name.downcase.include?('flower')
          payload_method = 'growth_cycle'
          client_method  = 'change_growth_phase'
        end

        payload = send("build_#{payload_method}_payload", batch)
        @logger.debug "[BATCH_MOVE] Metrc API request. URI #{@client.uri}, on #{payload_method}, payload #{payload}"
        @client.send(client_method, [payload])
        transaction.success = true
        @logger.info "[BATCH_MOVE] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
      rescue => exception # rubocop:disable Style/RescueStandardError
        @logger.error "[BATCH_MOVE] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
      ensure
        transaction.save
        @logger.debug "[BATCH_MOVE] Transaction: #{transaction.inspect}"
      end

      transaction
    end

    private

    def build_start_payload(batch)
      barcode_id = batch.relationships.dig('barcodes', 'data').first['id']

      {
        Name: barcode_id,
        Type: batch.attributes['seeding_unit']&.capitalize || 'Clone',
        Count: batch.attributes['quantity']&.to_i || 10,
        Strain: batch.attributes['crop_variety'],
        Room: batch.attributes['zone_name'] || 'Germination',
        PatientLicenseNumber: nil,
        ActualDate: batch.attributes['seeded_at']
      }
    end

    def build_discard_payload(batch)
      reason_note = 'Does not meet internal QC'
      reason_note = "#{batch.attributes['reason_type'].capitalize}: #{batch.attributes['reason_description']}" if batch.attributes['reason_type'] && batch.attributes['reason_description']

      {
        PlantBatch: batch.id,
        Count: batch.attributes['quantity']&.to_i,
        ReasonNote: reason_note,
        ActualDate: batch.attributes['dumped_at']
      }
    end

    def build_growth_cycle_payload(batch)
      barcodes = batch.included.find_all { |el| el['type'] == 'barcodes' }
                      .sort_by { |barcode| barcode['id'] }
      batch_barcode, start_tag = barcodes.values_at 0, -1

      {
        Name: batch_barcode,
        Count: batch.attributes['quantity']&.to_i || 1,
        StartingTag: start_tag,
        GrowthPhase: 'Flowering',
        Room: batch.attributes['zone_name'] || 'Germination',
        GrowthDate: DateTime.now.to_date.strftime('%F') # TODO: Fix the date below
      }
    end

    def build_move_payload(batch)
      barcode_id = batch.relationships.dig('barcodes', 'data').first['id']

      {
        Name: barcode_id,
        Room: batch.attributes['zone_name'] || 'Germination',
        MoveDate: DateTime.now.to_date.strftime('%F') # TODO: Fix the date below
      }
    end

    def get_batch(include = 'zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')
      ArtemisApi::Batch.find(@batch_id,
                             @facility_id,
                             @integration.account.client,
                             include: include)
    end
  end
end
