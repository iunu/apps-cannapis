class Integration < ApplicationRecord
  belongs_to :account
  has_many :transactions
  validates :account_id, presence: true

  # TODO: enable this when acts_as_paranoid supports AR +6.0
  # acts_as_paranoid
  scope :active, -> { where(deleted_at: nil) }
  scope :inactive, -> { where(deleted_at: nil) }
end
