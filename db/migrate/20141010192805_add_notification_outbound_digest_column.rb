class AddNotificationOutboundDigestColumn < ActiveRecord::Migration

  def self.up
    change_table :notification_outbounds do |t|
      t.boolean :is_digest
    end
  end

  def self.down
    change_table :notification_outbounds do |t|
      t.remove :is_digest
    end
  end

end
