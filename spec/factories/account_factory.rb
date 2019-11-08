FactoryBot.define do
  factory :account do
    artemis_id { 'imtheicedragon' }
    name { 'Jon Snow' }
    access_token { 'abc123' }
    refresh_token { 'abc123' }
    access_token_expires_in { Time.now + 1.day }
    access_token_created_at { Time.now }
  end
end
