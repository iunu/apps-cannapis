FactoryBot.define do
  factory :transaction do
    account
    integration

    batch_id { Faker::Number.number(digits: 4) }
    completion_id { Faker::Number.number(digits: 4) }
    vendor { :metrc }
    metadata { {} }
    created_at { Time.now.utc - 1.day }
    updated_at { Time.now.utc - 1.day }

    trait :successful do
      success { true }
    end

    trait :unsuccessful do
      success { false }
    end

    trait :discard do
      type { :discard_batch }
    end

    trait :harvest do
      type { :harvest_batch }
    end

    trait :move do
      type { :move_batch }
    end
  end
end
