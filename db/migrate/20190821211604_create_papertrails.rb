class CreatePapertrails < ActiveRecord::Migration[6.0]
  def change
    create_table :papertrails, &:timestamps
  end
end
