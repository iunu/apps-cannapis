class AddDisableHarvestsToIntegrations < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :disable_harvest, :boolean, default: false

    Integration.update_all(disable_harvest: false)
  end
end
