FactoryBot.define do
  factory :task, class: Scheduler do
    integration

    facility_id { Faker::Number.number(digits: 4) }
    batch_id { Faker::Number.number(digits: 4) }
    run_on { Time.now + 1.hour }
    received_at { Time.now - 1.hour }
  end
end
