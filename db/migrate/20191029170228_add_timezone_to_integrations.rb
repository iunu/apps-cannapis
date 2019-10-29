class AddTimezoneToIntegrations < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :timezone, :string, default: :utc
  end
end
