class ModifyNotificationSystem < ActiveRecord::Migration

  def self.up

    drop_table :aggregate_notifications
    drop_table :user_notification_settings
    drop_table :notification_emails

    create_table :notification_aggregates do |t|
      t.integer :score, default: 0
      t.integer :hide, default: 0
      t.belongs_to :user, index:true
      t.timestamps
    end

    create_table :notification_distributors do |t|
      t.belongs_to :notification_aggregate, index:true
      t.references :notification_distributable, polymorphic: true, index: true
      t.string :link_code
      t.integer :view_count, default:0
      t.integer :stop_request, default:0
      t.timestamps
    end

    create_table :notification_emails do |t|
      t.integer :sent, default:0
      t.integer :received, default:0
      t.string :receive_code
      t.timestamps
    end

    create_table :notification_mobiles do |t|
      t.integer :sent, default:0
      t.integer :received, default:0
      t.timestamps
    end

    create_table :notification_mms_messages do |t|
      t.integer :sent, default:0
      t.integer :received, default:0
      t.timestamps
    end

    create_table :user_notification_options do |t|
      t.string :email_digest_frequency
      t.belongs_to :user
      t.timestamps
    end

    create_table :user_notification_option_item do |t|
      t.integer :feed
      t.string :feed_priority
      t.integer :email
      t.string :email_frequency
      t.integer :mobile
      t.string :mobile_frequency
      t.integer :mms_message
      t.string :mms_message_frequency
      t.belongs_to :user_notification_option, index:true
      t.belongs_to :activity_option, index:true
      t.belongs_to :bookmarks, default: nil
      t.timestamps
    end

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

    change_column_default :aggregate_notifications, :click_count, 0
    change_column_default :aggregate_notifications, :score, 0

    change_column_default :notification_emails, :sent, 0
    change_column_default :notification_emails, :received, 0
    change_column_default :notification_emails, :click_count, 0

  end

end