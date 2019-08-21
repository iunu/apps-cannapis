class CreateTransactions < ActiveRecord::Migration[6.0]
  def change
    create_table :transactions, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.integer :batch_id, null: false
      t.integer :completion_id, null: false
      t.string :type, null: false
      t.boolean :success, null: false, default: false

      t.timestamps
    end

    add_index :transactions, :account_id
    add_index :transactions, :integration_id
    add_index :transactions, :batch_id
    add_index :transactions, :completion_id
    add_index :transactions, :type
    add_index :transactions, :success
  end
end
