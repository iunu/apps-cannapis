require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'sprockets/railtie'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Cannapi
  class Application < Rails::Application
    # Metrc.configure do |config|
    #   config.api_key = "hRUWxG5vydPpOlqdldox8Skh0UBWVsoa01PLAs5hTeP7lQoB"
    #   config.base_uri = 'https://sandbox-api-ca.metrc.com'
    #   config.state = :ca
    # end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.active_job.queue_adapter = Rails.env.development? ? :async : :sidekiq

    # Generate AR migration with UUID as primary keys
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    config.web_console.whiny_requests = false if ENV['WAIT_HOSTS'] # We're running on docker-compose!
  end
end
