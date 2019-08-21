class CreateTransactions < ActiveRecord::Migration[6.0]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.integer :batch_id, null: false
      t.integer :completion_id, null: false
      t.string :type, null: false
      t.boolean :success, null: false, default: false

      t.timestamps
    end
  end
end
