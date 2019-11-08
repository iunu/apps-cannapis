FactoryBot.define do
  factory :transaction do
    account
    integration

    batch_id { Faker::Number.number(digits: 4) }
    completion_id { Faker::Number.number(digits: 4) }
    type { :start_batch }
    success { true }
    metadata { {  } }
  end
end
