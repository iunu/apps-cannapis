FactoryBot.define do
  factory :account do
    sequence(:artemis_id) { |n| n }
    name { Faker::Name.name }
    access_token { Faker::Alphanumeric.unique.alphanumeric(number: 290) }
    refresh_token { Faker::Alphanumeric.unique.alphanumeric(number: 45) }
    access_token_expires_in { (Time.now.utc + 1.day).to_i }
    access_token_created_at { Time.now.utc }
  end

  trait :no_tokens do
    access_token { nil }
    refresh_token { nil }
    access_token_expires_in { nil }
    access_token_created_at { nil }
  end

  trait :expired_token do
    access_token_expires_in { (Time.now.utc - 1.day).to_i }
  end
end
