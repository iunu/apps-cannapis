class AddSyncHarvestsToIntegrations < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :sync_harvest, :boolean, null: false, default: true
  end
end
