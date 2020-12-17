class AddActivatedAtToIntegration < ActiveRecord::Migration[6.0]
  def change
    add_column :integrations, :activated_at, :datetime

    Integration.all.each do |integration|
      integration.update_column(:activated_at, integration.created_at)
    end
  end
end
