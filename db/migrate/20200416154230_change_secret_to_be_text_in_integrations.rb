class ChangeSecretToBeTextInIntegrations < ActiveRecord::Migration[6.0]
  def up
    change_column :integrations, :secret, :text
  end

  def down
    change_column :integrations, :secret, :string
  end
end
