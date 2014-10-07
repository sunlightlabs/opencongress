class AddDefaultValuesNotificationModels < ActiveRecord::Migration

  def self.up

    change_column_default :aggregate_notifications, :click_count, 0
    change_column_default :aggregate_notifications, :score, 0

    change_column_default :notification_emails, :sent, 0
    change_column_default :notification_emails, :received, 0
    change_column_default :notification_emails, :click_count, 0

  end

  def self.down

  end

end