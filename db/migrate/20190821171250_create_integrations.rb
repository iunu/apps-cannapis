class CreateIntegrations < ActiveRecord::Migration[6.0]
  def change
    create_table :integrations, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.integer :facility_id
      t.string :state
      t.string :vendor # Vendor name, in lowercase
      t.string :vendor_id # License number
      t.string :key # API Key or access token
      t.string :secret # API secret or token secret
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :integrations, :id, unique: true
    add_index :integrations, :facility_id
  end
end
