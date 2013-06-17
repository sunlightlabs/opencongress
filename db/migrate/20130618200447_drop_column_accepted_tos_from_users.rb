class DropColumnAcceptedTosFromUsers < ActiveRecord::Migration
  def self.up
    remove_column :users, :accepted_tos
  end

  def self.down
    add_column :users, :accepted_tos, :boolean, :default => false
  end
end
