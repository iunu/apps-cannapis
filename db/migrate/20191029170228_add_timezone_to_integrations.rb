class AddTimezoneToIntegrations < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :timezone, :string, default: '00:00'
  end
end
