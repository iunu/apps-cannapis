class Transaction < ApplicationRecord
  self.inheritance_column = :_type

  belongs_to :account
  belongs_to :integration
  validates :account_id, presence: true
  validates :integration_id, presence: true

  scope :skipped, -> { where(skipped: true) }
  scope :succeed, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
end
