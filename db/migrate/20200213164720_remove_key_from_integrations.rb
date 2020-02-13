class RemoveKeyFromIntegrations < ActiveRecord::Migration[6.0]
  def change
    remove_column :integrations, :key, :string
  end
end
