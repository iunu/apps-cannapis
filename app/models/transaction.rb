class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :integration

  scope :succeed, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
end
