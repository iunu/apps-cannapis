# frozen_string_literal: true

require 'pry'

namespace :metrc do
  # TODO: move Metrc client setup from here and metrc/base into a separate service
  task console: :environment do
    raise 'ARTEMIS_ID must be supplied' if ENV['ARTEMIS_ID'].nil?

    account = Account.find_by(artemis_id: ENV['ARTEMIS_ID'])
    integration = account.integrations.find_by(vendor: :metrc)

    debug = !ENV['DEMO'].nil? || Rails.env.development? || Rails.env.test?
    secret_key = ENV["METRC_SECRET_#{integration.state.upcase}"]

    Metrc.configure do |config|
      config.api_key = secret_key
      config.state = integration.state
      config.sandbox = debug
    end

    @client = Metrc::Client.new(user_key: integration.secret, debug: debug)

    puts 'Metrc client instantiated at: @client'
    Pry.start
  end
end
