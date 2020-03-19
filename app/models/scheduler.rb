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

  def reschedule!
    update!(
      attempts: attempts + 1,
      run_on: Time.now.utc + RESCHEDULE_DELAY
    )
  rescue ActiveRecord::RecordInvalid
    raise ScheduledJob::TooManyRetriesError if errors[:attempts].any?

    raise
  end
end
