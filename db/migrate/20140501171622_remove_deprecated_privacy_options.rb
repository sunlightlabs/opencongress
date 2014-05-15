class RemoveDeprecatedPrivacyOptions < ActiveRecord::Migration
  def self.up
    change_table :user_privacy_options do |t|
      t.remove :my_instant_messenger_names
      t.rename :my_tracked_items, :bookmarks
    end
  end

  def self.down
    change_table :user_privacy_options do |t|
      t.integer :my_instant_messenger_names, :default => 0
      t.rename :bookmarks, :my_tracked_items
    end
  end
end
