class AddIndexStatusOnUsers < ActiveRecord::Migration
  def self.up
    add_index :users, :status
  end

  def self.down
    remove_index :users, :status
  end
end
