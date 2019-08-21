class CreateAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :accounts, id: :uuid do |t|
      t.integer :artemis_id
      t.string :name
      t.string :access_token
      t.string :refresh_token
      t.integer :access_token_expires_in
      t.datetime :access_token_created_at

      t.timestamps
    end

    add_index :accounts, :id, unique: true
    add_index :accounts, :artemis_id, unique: true
  end
end
