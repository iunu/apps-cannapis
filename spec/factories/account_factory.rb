FactoryBot.define do
  factory :account do
    sequence(:artemis_id) { |n| n }
    name { Faker::Name.name }
    access_token { Faker::Alphanumeric.unique.alphanumeric(number: 10) }
    refresh_token { Faker::Alphanumeric.unique.alphanumeric(number: 10) }
    access_token_expires_in { Time.now.utc + 1.day }
    access_token_created_at { Time.now.utc }
  end

  factory :account_with_no_tokens, parent: :account do
    access_token { nil }
    refresh_token { nil }
    access_token_expires_in { nil }
    access_token_created_at { nil }
  end
end
