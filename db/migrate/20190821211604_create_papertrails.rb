class CreatePapertrails < ActiveRecord::Migration[6.0]
  def change
    create_table :papertrails do |t|

      t.timestamps
    end
  end
end
