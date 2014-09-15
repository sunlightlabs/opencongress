class ChangeNotificationField < ActiveRecord::Migration
  def self.up
    rename_column :notifications, :notifying_object, :notifying_object_id
  end

  def self.down
    rename_column :notifications, :notifying_object_id, :notifying_object
  end
end