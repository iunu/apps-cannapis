require 'pp'

class SubscriptionJob < ApplicationJob
  queue_as :default

  def perform(base_url, integration)
    logger = Rails.logger
    facility_id = integration.facility_id
    account_id = integration.account.id

    begin
      logger.error "[SUBSCRIPTION] Start: facility ID #{facility_id}, account ID #{account_id}"

      ArtemisApi::Subscription.create(facility_id: facility_id,
                                      subject: :completions,
                                      destination: "#{base_url}/v1/webhook",
                                      client: integration.account.client)x

      logger.error "[SUBSCRIPTION] Success: facility ID #{facility_id}, account ID #{account_id}"
    rescue => exception
      logger.error "[SUBSCRIPTION] Failed: facility ID #{facility_id}, account ID #{account_id}; #{exception.inspect}"
    end
  end
end
