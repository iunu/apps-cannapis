class MetrcService < ApplicationService
  CANNABIS = 'cannabis'.freeze

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
                                    include: 'zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')

    raise 'Batch crop is not cannabis' unless batch.crop.downcase == CANNABIS

    payload = build_start_payload(batch)
    puts "\nMetrc API Request debug\n#{client.uri}\n########################\n" if client.debug
    client.create_plant_batches(@integration.vendor_id, [payload])
  end

  def discard_batch
    @integration.account.refresh_token_if_needed
    client = metrc_client
    batch  = ArtemisApi::Discard.find(@ctx[:relationships][:action_result][:data][:id],
                                      @facility_id,
                                      @integration.account.client,
                                      include: 'batch,barcodes')
    payload = build_discard_payload(batch)
    puts "\nMetrc API Request debug\n#{client.uri}\n########################\n" if client.debug
    client.destroy_plant_batches(@integration.vendor_id, [payload])
  end

  private

  def build_start_payload(batch) # rubocop:disable Metrics/AbcSize
    puts "\n########################\n#{batch.relationships}\n########################"
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
