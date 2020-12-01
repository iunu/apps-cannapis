class AddSkippedToTransactions < ActiveRecord::Migration[6.0]
  def change
    add_column :transactions, :skipped, :boolean, default: false

    Transaction.update_all(skipped: true)
  end
end
