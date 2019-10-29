class Scheduler < ApplicationRecord
  belongs_to :integration
  validates :facility_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :batch_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :integration_id, presence: true
  validates :run_on, presence: true
end
