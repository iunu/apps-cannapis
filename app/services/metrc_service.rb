class MetrcService < ApplicationService
  def initialize(ctx, integration)
    @batch_id    = ctx.dig(:relationships, :batch, :data, :id)
    @facility_id = ctx.dig(:relationships, :facility, :data, :id)
    @ctx         = ctx
    @integration = integration
  end

  def start_batch
    @integration.account.refresh_token_if_needed
    client = metrc_client
    batch  = ArtemisApi::Batch.find(@batch_id,
                                    @facility_id,
                                    @integration.account.client,
                                    include: 'zone,barcodes')

    return unless batch.crop == 'Cannabis'

    payload = build_start_payload(batch)
    client.create_plant_batches(@integration.vendor_id, [payload])
  end

  def discard_batch
    @integration.account.refresh_token_if_needed
    client = metrc_client
    batch  = ArtemisApi::BatchDiscards.find(@ctx[:relationships][:action_result][:data][:id],
                                            @facility_id,
                                            @integration.account.client,
                                            include: 'batch,barcodes')
    payload = build_discard_payload(batch)
    client.destroy_plant_batches(@integration.vendor_id, [payload])
  end

  private

  def build_start_payload(batch) # rubocop:disable Metrics/AbcSize
    barcode_id = batch.relationships.dig('barcodes', 'data')&.first || ['id']
    {
      'Name': barcode_id,
      'Type': batch.attributes['seeding_unit']&.capitalize,
      'Count': batch.attributes['quantity']&.to_i,
      'Strain': batch.attributes['crop_variety'],
      'Room': batch.attributes['zone_name'],
      'PatientLicenseNumber': nil,
      'ActualDate': batch.attributes['seeded_at']
    }
  end

  def build_discard_payload(batch) # rubocop:disable Metrics/AbcSize
    reason_note = 'Does not meet internal QC'
    reason_note = "#{batch.attributes['reason_type'].capitalize}: #{batch.attributes['reason_description']}" if batch.attributes['reason_type'] && batch.attributes['reason_description']

    {
      'PlantBatch': batch.id,
      'Count': batch.attributes['quantity']&.to_i,
      'ReasonNote': reason_note,
      'ActualDate': batch.attributes['dumped_at']
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
end
