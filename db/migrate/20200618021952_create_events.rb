class CreateEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :events, id: :uuid do |t|
      t.integer :facility_id, null: false
      t.integer :batch_id, null: false
      t.integer :user_id, null: false
      t.json :body

      t.timestamps
    end
  end
end
