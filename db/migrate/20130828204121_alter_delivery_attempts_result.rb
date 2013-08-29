class AlterDeliveryAttemptsResult < ActiveRecord::Migration
  def self.up
    change_column :formageddon_delivery_attempts, :result, :text
  end

  def self.down
    change_column :formageddon_delivery_attempts, :result, :string
  end
end
