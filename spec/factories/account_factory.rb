FactoryBot.define do
  factory :account do
    artemis_id { Faker::Alphanumeric.alphanumeric }
    name { Faker::Name.name }
    access_token { Faker::Alphanumeric.alphanumeric(number: 10) }
    refresh_token { Faker::Alphanumeric.alphanumeric(number: 10) }
    access_token_expires_in { Time.now + 1.day }
    access_token_created_at { Time.now }
  end

  factory :account_with_no_tokens, parent: :account do
    access_token { nil }
    refresh_token { nil }
    access_token_expires_in { nil }
    access_token_created_at { nil }
  end
end
