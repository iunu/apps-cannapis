FactoryBot.define do
  factory :transaction do
    account
    integration

    batch_id { Faker::Number.number(digits: 4) }
    completion_id { Faker::Number.number(digits: 4) }
    metadata { {  } }

    trait :succeed do
      success { true }
    end

    trait :unsucceed do
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
