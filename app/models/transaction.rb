class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :integration
  validates :account_id, presence: true
  validates :integration_id, presence: true

  scope :succeed, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
end
