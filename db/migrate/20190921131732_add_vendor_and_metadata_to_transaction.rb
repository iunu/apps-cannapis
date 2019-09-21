class AddVendorAndMetadataToTransaction < ActiveRecord::Migration[6.0]
  def change
    change_table :transactions, bulk: true do |t|
      t.string :vendor, null: false
      t.json :metadata
    end
  end
end
