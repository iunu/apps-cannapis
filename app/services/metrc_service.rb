class MetrcService < ApplicationService
  def initialize(ctx, integration)
    @batch_id    = ctx.dig(:relationships, :batch, :data, :id)
    @facility_id = ctx.dig(:relationships, :facility, :data, :id)
    @integration = integration
  end

  def start_batch
    client = metrc_client(@integration.key, @integration.secret, @integration.state)
    puts "\nMetrc API Request debug\n#{client.uri}\n########################\n"
    batch = ArtemisApi::Batch.find(@batch_id,
                                   @facility_id,
                                   @integration.account.client,
                                   include: %i[zone barcodes])
    # barcode = batch
    payload = build_start_payload(batch)
    client.create_plant_batches(@integration.vendor_id, [payload])
  end

  private

  def build_start_payload(batch)
    {
      'Name': batch.relationships.dig('barcodes', 'data', 'id'),
      'Type': batch.attributes['seeding_unit']&.capitalize,
      'Count': batch.attributes['quantity']&.to_i,
      'Strain': batch.attributes['crop_variety'],
      'Room': batch.attributes['zone_name'],
      'PatientLicenseNumber': nil,
      'ActualDate': batch.attributes['seeded_at']
    }
  end

  def metrc_client(api_key, user_key, state)
    Metrc.configure do |config|
      config.api_key  = api_key
      config.state    = state.to_sym
      config.sandbox  = Rails.env.development?
    end

    Metrc::Client.new(user_key: user_key,
                      debug: Rails.env.development?)
  end
end
