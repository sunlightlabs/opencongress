class AddGroupsToUserPrivacyOptions < ActiveRecord::Migration
  def self.up
    add_column :user_privacy_options, :groups, :integer, :default => 0
  end

  def self.down
    remove_column :user_privacy_options, :groups
  end
end
