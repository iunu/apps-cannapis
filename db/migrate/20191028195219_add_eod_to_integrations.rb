class AddEodToIntegrations < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :eod, :time, default: '19:00:00', null: false
  end
end
