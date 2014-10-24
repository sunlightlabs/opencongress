class AddClickCountNotificationAggregates < ActiveRecord::Migration

  def self.up
    change_table :notification_aggregates do |t|
      t.integer :click_count, default: 0
    end
  end

  def self.down
    change_table :notification_aggregates do |t|
      t.remove :click_count
    end
  end

end