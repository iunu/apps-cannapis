module MetrcService
  CROP = 'Cannabis'.freeze
  GROWTH_CYCLES = {
    clone: %i[clone vegetative],
    vegetative: %i[vegetative flowering],
    flowering: %i[flowering]
  }.freeze

  def self.logger
    @logger ||= Rails.logger
  end

  def self.client(integration)
    return @client if @client

    Metrc.configure do |config|
      config.api_key  = integration.key
      config.state    = integration.state
      config.sandbox  = Rails.env.development?
    end

    @client = Metrc::Client.new(user_key: integration.secret,
                                debug: Rails.env.development?)

    @client
  end

  def self.transaction(integration, batch_id, completion_id, name, metadata)
    Transaction.find_or_create_by(account: integration.account,
                                  vendor: :metrc,
                                  integration: integration,
                                  batch_id: batch_id,
                                  completion_id: completion_id,
                                  type: name,
                                  metadata: metadata)
  end
end
