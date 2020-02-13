FactoryBot.define do
  factory :integration do
    account

    secret { Faker::Alphanumeric.unique.alphanumeric(number: 10) }
    key { Faker::Alphanumeric.unique.alphanumeric(number: 7) }
    state { Faker::Address.state_abbr.downcase }
    facility_id { Faker::Number.number(digits: 4) }
    vendor { :metrc }
    vendor_id { 'LIC-0001' }
    eod { "#{Time.now.utc.hour}:00" }
    timezone { '+00:00' }

    factory :integration_with_metrc_creds do
      secret { ENV['METRC_API_SECRET'] }
      key { ENV['METRC_API_KEY'] }
      state { ENV['METRC_API_STATE'] }
      vendor { :metrc }
      vendor_id { ENV['METRC_API_LICENSE'] }
    end
  end
end
