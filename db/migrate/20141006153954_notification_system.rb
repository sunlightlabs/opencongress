class NotificationSystem < ActiveRecord::Migration
  def self.up

    create_table :activity_options do |t|
      t.string :key, index:true
      t.timestamps
    end

    create_table :aggregate_notifications do |t|
      t.integer :click_count
      t.integer :score
      t.belongs_to :user, index:true
      t.timestamps
    end

    create_table :notification_emails do |t|
      t.integer :sent
      t.integer :received
      t.string :code
      t.integer :click_count
      t.belongs_to :aggregate_notification,  index:true
      t.timestamps
    end

    create_table :user_notification_settings do |t|
      t.string :timeframe
      t.integer :threshold
      t.string :email_freq
      t.belongs_to :user, index: true
      t.belongs_to :activity_option, index: true
      t.timestamps
    end

    change_table :notifications do |t|
      t.remove :seen
      t.remove :user_id
      t.belongs_to :aggregate_notification, index:true
    end

  end

  def self.down

    drop_table :activity_options
    drop_table :aggregate_notifications
    drop_table :notification_emails
    drop_table :user_notification_settings
    change_table :notifications do |t|
      t.integer :seen
      t.belongs_to :user
      t.remove :aggregate_notification
    end

  end
end
