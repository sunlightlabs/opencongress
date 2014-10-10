class AddNotificationOptionTimeFrame < ActiveRecord::Migration

  def self.up
    change_table :user_notification_option_items do |t|
      t.integer :aggregate_timeframe, default: 21600
    end
  end

  def self.down
    change_table :user_notification_option_items do |t|
      t.remove :aggregate_timeframe
    end
  end

end