module MetrcService
  class Base
    def initialize(ctx, integration)
      @integration   = integration
      @relationships = ctx[:relationships]
      @attributes    = ctx[:attributes]
      @completion_id = ctx[:id]
      @batch_id      = @relationships.dig(:batch, :data, :id)
      @facility_id   = @relationships.dig(:facility, :data, :id)
      @logger        = Rails.logger
      @client        = client
    end

    private

    def client
      return @client if @client

      debug = Rails.env.development? || Rails.env.test?

      Metrc.configure do |config|
        config.api_key  = @integration.key
        config.state    = @integration.state
        config.sandbox  = debug
      end

      @client = Metrc::Client.new(user_key: @integration.secret, debug: debug)
      @client
    end

    protected

    def get_transaction(name, metadata = @attributes)
      Transaction.find_or_create_by(account: @integration.account,
                                    vendor: :metrc,
                                    integration: @integration,
                                    batch_id: @batch_id,
                                    completion_id: @completion_id,
                                    type: name,
                                    metadata: metadata)
    end

    def get_batch(include = 'zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')
      ArtemisApi::Batch.find(@batch_id,
                             @facility_id,
                             @integration.account.client,
                             include: include)
    end

    def get_items(seeding_unit_id, include: 'barcodes,seeding_unit')
      ArtemisApi::Items.find_all(@facility_id,
                                 @batch_id,
                                 @integration.account.client,
                                 seeding_unit_id: seeding_unit_id,
                                 include: include)
    end
  end
end
