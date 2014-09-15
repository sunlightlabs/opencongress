class AddNotificationField < ActiveRecord::Migration
  def self.up
    add_column :notifications, :notifying_object_type, :string
  end

  def self.down
    remove_column :notifications, :notifying_object_type, :string
  end
end
