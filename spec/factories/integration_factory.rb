require 'securerandom'

FactoryBot.define do
  factory :integration do
    account

    id { SecureRandom.uuid }
    secret { 'jonisdany\'snephew' }
    key { 'jonsnow' }
    state { :cb }
    facility_id { 1568 }
    vendor { :metrc }
    vendor_id { 'LIC-0001' }
    eod { Time.now.hour }
    timezone { '+00:00' }
  end
end
