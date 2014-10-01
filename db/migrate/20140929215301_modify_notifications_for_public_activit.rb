class ModifyNotificationsForPublicActivit < ActiveRecord::Migration
  def self.up
    remove_column :notifications, :notifying_object_type, :string
    remove_column :notifications, :notifying_object_id, :integer
    add_reference :notifications, :activities, index:true
  end

  def self.down
    add_column :notifications, :notifying_object_type, :string
    add_column :notifications, :notifying_object_id, :integer
  end
end
