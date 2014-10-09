class ModifyNotificationSystem < ActiveRecord::Migration

  def self.up

    drop_table :aggregate_notifications
    drop_table :user_notification_settings
    drop_table :notification_emails
    drop_table :notifications

    create_table :notification_aggregates do |t|
      t.integer :score, default: 0
      t.integer :hide, default: 0
      t.belongs_to :user, index:true
      t.timestamps
    end

    create_table :notification_items do |t|
      t.belongs_to :notification_aggregate, index:true
      t.belongs_to :activities, index:true
      t.timestamps
    end

    create_table :notification_outbounds do |t|
      t.integer :sent, default:0
      t.integer :received, default:0
      t.string :receive_code
      t.string :outbound_type
      t.timestamps
    end

    create_table :notification_distributors do |t|
      t.belongs_to :notification_aggregate, index:true
      t.belongs_to :notification_outbound, index:true
      t.string :link_code
      t.integer :view_count, default:0
      t.integer :stop_request, default:0
      t.timestamps
    end

    create_table :user_notification_options do |t|
      t.string :email_digest_frequency
      t.belongs_to :user
      t.timestamps
    end

    create_table :user_notification_option_items do |t|
      t.integer :feed
      t.string :feed_priority
      t.integer :email
      t.string :email_frequency
      t.integer :mobile
      t.string :mobile_frequency
      t.integer :mms_message
      t.string :mms_message_frequency
      t.belongs_to :user_notification_option
      t.belongs_to :activity_option, index:true
      t.belongs_to :bookmark, default: nil, index:true
      t.timestamps
    end

    add_index :user_notification_option_items, :user_notification_option_id, name: 'index_unoi_on_uno_id'

    change_table :activity_options do |t|
      t.string :owner_model
      t.string :trackable_model
      t.index :key
    end

  end

  def self.down

    create_table :aggregate_notifications do |t|
      t.integer :click_count
      t.integer :score
      t.belongs_to :user, index:true
      t.timestamps
    end

    create_table :notifications do |t|
      t.belongs_to :aggregate_notifications, index:true
      t.belongs_to :activities, index:true
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

    drop_table :notification_aggregates
    drop_table :notification_outbounds
    drop_table :notification_distributors
    drop_table :user_notification_options
    drop_table :user_notification_option_items

    remove_column :activity_options, :owner_model
    remove_column :activity_options, :trackable_model

  end

end