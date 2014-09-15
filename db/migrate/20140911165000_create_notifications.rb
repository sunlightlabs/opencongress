class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.integer :user_id
      t.integer :notifying_object
      t.integer :seen

      t.timestamps
    end
  end
end
