class MetrcService < ApplicationService
  attr_reader :client, :integration
  SUPPORTED_STATES = %w[ca md oh ma].freeze

  def initialize(integration)
    Metrc.configure do |config|
      config.api_key = integration.key
      config.state = integration.state&.to_sym || :md
      config.sandbox = Rails.env.development?
    end

    @client = Metrc::Client.new
    @integration = integration
  end

  def report_start_batch(ctx)
    batch_id = ctx.relationships.batch.data.id
    facility_id = ctx.relationships.facility.data.id
    user_id = ctx.relationships.user.data.id
    account = @integration.account
  end
end
