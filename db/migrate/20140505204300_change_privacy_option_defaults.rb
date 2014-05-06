class ChangePrivacyOptionDefaults < ActiveRecord::Migration
  def self.up
    change_column_default :user_privacy_options, :name, 1
    change_column_default :user_privacy_options, :zipcode, 1
    change_column_default :user_privacy_options, :location, 2
    change_column_default :user_privacy_options, :profile, 2
    change_column_default :user_privacy_options, :actions, 1
    change_column_default :user_privacy_options, :bookmarks, 1
    change_column_default :user_privacy_options, :friends, 1
    change_column_default :user_privacy_options, :groups, 1
  end

  def self.down
    change_column_default :user_privacy_options, :name, 0
    change_column_default :user_privacy_options, :zipcode, 0
    change_column_default :user_privacy_options, :location, 0
    change_column_default :user_privacy_options, :profile, 0
    change_column_default :user_privacy_options, :actions, 0
    change_column_default :user_privacy_options, :bookmarks, 0
    change_column_default :user_privacy_options, :friends, 0
    change_column_default :user_privacy_options, :groups, 0
  end
end
