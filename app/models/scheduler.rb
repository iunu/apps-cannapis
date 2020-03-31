class Scheduler < ApplicationRecord
  MAX_ATTEMPTS = 4
  RESCHEDULE_DELAY = 3600

  attr_accessor :current_action

  belongs_to :integration
  validates :facility_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :batch_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :integration_id, presence: true
  validates :run_on, presence: true
  validates :attempts, numericality: { only_integer: true, less_than: MAX_ATTEMPTS }

  # scope :for_today do |timezone|
  #   now = Time.now.getlocal(timezone)
  #   where(run_on: now.at_beginning_of_day..now.at_end_of_day)
  # end

  def reschedule!
    update!(
      attempts: attempts + 1,
      run_on: Time.now.utc + RESCHEDULE_DELAY
    )
  rescue ActiveRecord::RecordInvalid
    raise Cannapi::TooManyRetriesError if errors[:attempts].any?

    raise
  end
end
