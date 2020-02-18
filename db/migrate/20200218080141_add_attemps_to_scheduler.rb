class AddAttempsToScheduler < ActiveRecord::Migration[6.0]
  def change
    add_column :schedulers, :attempts, :integer, default: 0
  end
end
