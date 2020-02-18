FactoryBot.define do
  factory :task, class: Scheduler do
    integration

    facility_id { Faker::Number.number(digits: 4) }
    batch_id { Faker::Number.number(digits: 4) }
    run_on { Time.now.utc + 1.hour }
    received_at { Time.now.utc - 1.hour }
  end
end
