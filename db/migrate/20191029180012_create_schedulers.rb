class CreateSchedulers < ActiveRecord::Migration[6.0]
  def change
    create_table :schedulers, id: :uuid do |t|
      t.references :integration, null: false, foreign_key: true, type: :uuid
      t.integer :facility_id, null: false
      t.integer :batch_id, null: false
      t.timestamp :run_on, null: false
      t.timestamp :received_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :schedulers, %i[batch_id facility_id]
    add_index :schedulers, :facility_id
    add_index :schedulers, :run_on
  end
end
