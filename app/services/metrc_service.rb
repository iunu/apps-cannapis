class MetrcService < ApplicationService
  CROP = 'Cannabis'.freeze

  def initialize(ctx, integration)
    @batch_id      = ctx.dig(:relationships, :batch, :data, :id)
    @facility_id   = ctx.dig(:relationships, :facility, :data, :id)
    @completion_id = ctx[:id]
    @ctx           = ctx
    @integration   = integration
  end

  def start_batch
    Rails.logger.info "[START_BATCH] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
    transaction = lookup_transaction :start_batch

    if transaction.success
      Rails.logger.error "[START_BATCH] Success: transaction previously performed. #{transaction.inspect}"
      return
    end

    begin
      @integration.account.refresh_token_if_needed
      client = metrc_client
      batch  = ArtemisApi::Batch.find(@batch_id,
                                      @facility_id,
                                      @integration.account.client,
                                      include: 'zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')

      unless batch.crop == CROP
        Rails.logger.error "[START_BATCH] Failed: Crop is not #{CROP} but #{batch.crop}. batch ID #{@batch_id}, completion ID #{@completion_id}"
        return
      end

      payload = build_start_payload(batch)
      Rails.logger.debug "[START_BATCH] Metrc API request. URI #{client.uri}, payload #{payload}"
      client.create_plant_batches(@integration.vendor_id, [payload])
      transaction.success = true
      Rails.logger.info "[START_BATCH] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
    rescue => exception
      Rails.logger.error "[START_BATCH] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
    ensure
      transaction.save
      Rails.logger.debug "[START_BATCH] Transaction: #{transaction.inspect}"
    end

    transaction
  end

  def discard_batch
    Rails.logger.info "[DISCARD_BATCH] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
    transaction = lookup_transaction :discard_batch

    if transaction.success
      Rails.logger.error "[DISCARD_BATCH] Success: transaction previously performed. #{transaction.inspect}"
      return
    end

    begin
      @integration.account.refresh_token_if_needed
      client = metrc_client
      batch  = ArtemisApi::Discard.find(@ctx[:relationships][:action_result][:data][:id],
                                        @facility_id,
                                        @integration.account.client,
                                        include: 'batch,barcodes')
      payload = build_discard_payload(batch)
      Rails.logger.debug "[DISCARD_BATCH] Metrc API request. URI #{client.uri}, payload #{payload}"
      client.destroy_plant_batches(@integration.vendor_id, [payload])
      transaction.success = true
      Rails.logger.info "[DISCARD_BATCH] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
    rescue => exception
      Rails.logger.error "[DISCARD_BATCH] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
    ensure
      transaction.save
      Rails.logger.debug "[DISCARD_BATCH] Transaction: #{transaction.inspect}"
    end

    transaction
  end

  def move_batch
    Rails.logger.info "[MOVE_BATCH] Started: batch ID #{@batch_id}, completion ID #{@completion_id}"
    transaction = lookup_transaction :move_batch

    if transaction.success
      Rails.logger.error "[MOVE_BATCH] Success: transaction previously performed. #{transaction.inspect}"
      return
    end

    begin
      @integration.account.refresh_token_if_needed
      client = metrc_client
      batch  = ArtemisApi::Batch.find(@batch_id,
                                      @facility_id,
                                      @integration.account.client,
                                      include: 'zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')

      zone_name = @ctx.dig(:data, :attributes, :options, :zone_name)
      payload_method = 'move'
      client_method  = 'move_plant_batches'

      if zone_name.downcase.include?('flower')
        payload_method = 'growth_cycle'
        client_method  = 'change_growth_phase'
      end

      payload = send("build_#{payload_method}_payload", batch)
      Rails.logger.debug "[MOVE_BATCH] Metrc API request. URI #{client.uri}, on #{payload_method}, payload #{payload}"
      client.send(client_method, [payload])
      transaction.success = true
      Rails.logger.info "[MOVE_BATCH] Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}"
    rescue => exception
      Rails.logger.error "[MOVE_BATCH] Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{exception.inspect}"
    ensure
      transaction.save
      Rails.logger.debug "[MOVE_BATCH] Transaction: #{transaction.inspect}"
    end

    transaction
  end

  private

  def build_start_payload(batch)
    barcode_id = batch.relationships.dig('barcodes', 'data').first['id']
    {
      'Name': barcode_id,
      'Type': batch.attributes['seeding_unit']&.capitalize || 'Seed',
      'Count': batch.attributes['quantity']&.to_i || 1,
      'Strain': batch.attributes['crop_variety'],
      'Room': batch.attributes['zone_name'] || 'Germination',
      'PatientLicenseNumber': nil,
      'ActualDate': batch.attributes['seeded_at']
    }
  end

  def build_discard_payload(batch)
    reason_note = 'Does not meet internal QC'
    reason_note = "#{batch.attributes['reason_type'].capitalize}: #{batch.attributes['reason_description']}" if batch.attributes['reason_type'] && batch.attributes['reason_description']

    {
      'PlantBatch': batch.id,
      'Count': batch.attributes['quantity']&.to_i,
      'ReasonNote': reason_note,
      'ActualDate': batch.attributes['dumped_at']
    }
  end

  def build_growth_cycle_payload(batch)
    barcodes = batch.included.find_all { |el| el['type'] == 'barcodes' }
                    .sort_by { |barcode| barcode['id'] }
    batch_barcode, start_tag = barcodes.values_at 0, -1

    {
      'Name': batch_barcode,
      'Count': batch.attributes['quantity']&.to_i || 1,
      'StartingTag': start_tag,
      'GrowthPhase': 'Flowering',
      'Room': batch.attributes['zone_name'] || 'Germination',
      # TODO: Fix the date below
      'GrowthDate': DateTime.now.to_date.strftime('%F')
    }
  end

  def build_move_payload(batch)
    barcode_id = batch.relationships.dig('barcodes', 'data').first['id']

    {
      'Name': barcode_id,
      'Room': batch.attributes['zone_name'] || 'Germination',
      # TODO: Fix the date below
      'MoveDate': DateTime.now.to_date.strftime('%F')
    }
  end

  def metrc_client
    Metrc.configure do |config|
      config.api_key  = @integration.key
      config.state    = @integration.state
      config.sandbox  = Rails.env.development?
    end

    Metrc::Client.new(user_key: @integration.secret,
                      debug: Rails.env.development?)
  end

  def lookup_transaction(name)
    Transaction.find_or_create_by(account: @integration.account,
                                  integration: @integration,
                                  batch_id: @batch_id,
                                  completion_id: @completion_id,
                                  type: name)
  end
end
