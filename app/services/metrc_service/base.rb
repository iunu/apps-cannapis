module MetrcService
  class Base
    def initialize(ctx, integration, batch = nil)
      @relationships = ctx[:relationships]
      @completion_id = ctx[:id]
      @integration = integration
      @attributes  = ctx[:attributes]
      @facility_id = @relationships&.dig(:facility, :data, :id)
      @batch_id = @relationships&.dig(:batch, :data, :id)
      @artemis  = @integration.account.client
      @logger = Rails.logger
      @client = client
      @batch  = batch if batch
    end

    def self.call(*args, &block)
      new(*args, &block).call
    end

    private

    def client
      return @client if @client

      debug = !ENV['DEMO'].nil? || Rails.env.development? || Rails.env.test?
      secret_key = ENV["METRC_SECRET_#{@integration.key.upcase}"]

      unless secret
        throw "No Metrc key is available for #{@integration.key.upcase}"
      end

      Metrc.configure do |config|
        config.api_key  = secret_key
        config.state    = state
        config.sandbox  = debug
      end

      @client = Metrc::Client.new(user_key: @integration.secret, debug: debug)
      @client
    end

    protected

    def state
      config[:state_map].fetch(@integration.state.upcase.to_sym, @integration.state)
    end

    def get_transaction(name, metadata = @attributes)
      transaction = Transaction.where('(vendor = ? AND account_id = ?) AND (integration_id = ? AND batch_id = ?) AND (completion_id = ? AND type = ?)',
                                      :metrc, @integration.account.id, @integration.id, @batch_id, @completion_id, name)&.first

      return transaction unless transaction.nil?

      Transaction.create(account: @integration.account,
                         vendor: :metrc,
                         integration: @integration,
                         batch_id: @batch_id,
                         completion_id: @completion_id,
                         type: name,
                         metadata: metadata)
    end

    def get_batch(include = 'zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')
      @artemis.facility(@facility_id)
              .batch(@batch_id, include: include)
    end

    def get_items(seeding_unit_id, include: 'barcodes,seeding_unit')
      @artemis.facility(@facility_id)
              .batch(@batch_id)
              .items(seeding_unit_id: seeding_unit_id, include: include)
    end

    def get_zone(zone_id, include: nil)
      @artemis.facility(@facility_id)
              .zone(zone_id, include: include)
    end

    def config
      @config ||= Rails.application.config_for('providers/metrc')
    end
  end
end
