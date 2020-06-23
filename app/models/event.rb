class Event < ApplicationRecord
  validates :facility_id, :batch_id, :user_id, presence: true

  def integration
    Integration.find_by(facility_id: facility_id)
  end

  def user
    Account.find_by(artemis_id: user_id)
  end
end
