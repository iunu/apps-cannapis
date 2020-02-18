require_relative '../common/base_service_action'

module MetrcService
  class Base < Common::BaseServiceAction
    class InvalidBatch < StandardError; end
    class BatchCropInvalid < StandardError; end
    class InvalidOperation < StandardError; end

    attr_reader :transaction

    def initialize(ctx, integration, batch = nil)
      @ctx = ctx
      @relationships = ctx[:relationships]
      @completion_id = ctx[:id]
      @integration = integration
      @attributes  = ctx[:attributes]
      @facility_id = @relationships&.dig(:facility, :data, :id)
      @batch_id = @relationships&.dig(:batch, :data, :id)
      @artemis  = @integration.account.client
      @client = build_client
      @batch  = batch if batch

      super
    end

    def run(*)
      super
    rescue BatchCropInvalid
      log("Failed: Crop is not #{CROP} but #{batch.crop}. Batch ID #{@batch_id}, completion ID #{@completion_id}")
      fail!
    rescue InvalidBatch, InvalidOperation => e
      log(e.message)
      fail!
    rescue StandardError => e
      log("Failed: batch ID #{@batch_id}, completion ID #{@completion_id}; #{e.inspect}", :error)
      fail!(transaction)
    end

    private

    attr_reader :client

    def build_client
      debug = !ENV['DEMO'].nil? || Rails.env.development? || Rails.env.test?
      secret_key = ENV["METRC_SECRET_#{@integration.key.upcase}"]

      throw "No Metrc key is available for #{@integration.key.upcase}" unless secret

      Metrc.configure do |config|
        config.api_key  = secret_key
        config.state    = state
        config.sandbox  = debug
      end

      Metrc::Client.new(user_key: @integration.secret, debug: debug)
    end

    protected

    def before
      log("Started: batch ID #{@batch_id}, completion ID #{@completion_id}")

      super

      validate_batch! unless @batch_id.nil?
    end

    def call
      super
    ensure
      transaction.save
      log("Transaction: #{transaction.inspect}", :debug)
    end

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

    def batch
      @batch ||= get_batch
    end

    def validate_batch!
      raise BatchCropInvalid unless batch.crop == MetrcService::CROP
    end

    def get_batch(include = 'zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
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
