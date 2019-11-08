FactoryBot.define do
  factory :integration do
    account

    id { SecureRandom.uuid }
    secret { Faker::Alphanumeric.alphanumeric(number: 10) }
    key { Faker::Alphanumeric.alphanumeric(number: 7) }
    state { Faker::Address.state_abbr.downcase }
    facility_id { Faker::Number.number(digits: 4) }
    vendor { :metrc }
    vendor_id { 'LIC-0001' }
    eod { "#{Time.now.hour}:00" }
    timezone { '+00:00' }
  end
end
