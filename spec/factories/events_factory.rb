FactoryBot.define do
  factory :event do
    facility_id { Faker::Number.number(digits: 4) }
    batch_id { Faker::Number.number(digits: 4) }
    sequence(:user_id) { |n| n }
    body { {} }
  end
end
