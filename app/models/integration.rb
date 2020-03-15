class Integration < ApplicationRecord
  belongs_to :account
  has_many :transactions # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :schedulers # rubocop:disable Rails/HasManyOrHasOneDependent
  validates :account_id, :state, :vendor, :vendor_id, presence: true
  validates :facility_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :vendor, presence: true
  validates :eod, presence: true

  before_save { self.vendor.downcase! } # rubocop:disable Style/RedundantSelf

  # TODO: enable this when acts_as_paranoid supports AR +6.0
  # acts_as_paranoid
  scope :active, -> { where(deleted_at: nil) }
  scope :inactive, -> { where.not(deleted_at: nil) }

  def vendor_name
    vendor.capitalize
  end

  def vendor_module
    "#{vendor.camelize}Service".constantize
  end
end
