class AddActivatedAtToIntegration < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :activated_at, :datetime
  end
end
