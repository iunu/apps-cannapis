class ChangeVendorIdToBeLicenseInIntegrations < ActiveRecord::Migration[6.0]
  def up
    rename_column :integrations, :vendor_id, :license
  end

  def down
    rename_column :integrations, :license, :vendor_id
  end
end
