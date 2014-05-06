##
# This migration adds tables for new models: UserProfile, UserOptions,
# and renames PrivacyOption to UserPrivacyOptions.
#
# The only code changes that need to accompany it deal with PrivacyOption relations.
#
require 'full-name-splitter'

class CreateUserProfileAndRenamePrivacyOption < ActiveRecord::Migration
  def self.up
    create_table :user_profiles do |t|
      t.integer :user_id
      t.string  :first_name
      t.string  :last_name
      t.string  :website
      t.text    :about
      t.string  :main_picture
      t.string  :small_picture
      t.string  :street_address
      t.string  :street_address_2
      t.string  :city
      t.string  :zipcode,               :limit => 5
      t.string  :zip_four,              :limit => 4
      t.string  :mobile_phone
    end

    create_table :user_options do |t|
      t.integer :user_id
      t.integer :comment_threshold,     :default => 5
      t.boolean :opencongress_mail,     :default => true
      t.boolean :partner_mail,          :default => false
      t.boolean :sms_notifications,     :default => false
      t.boolean :email_notifications,   :default => true
      t.string  :feed_key
    end

    rename_table :privacy_options, :user_privacy_options
    change_table :user_privacy_options do |t|
      t.rename :my_full_name, :name
      t.rename :my_email, :email
      t.rename :my_zip_code, :zipcode
      t.rename :my_location, :location
      t.rename :about_me, :profile
      t.rename :my_actions, :actions
      t.rename :my_friends, :friends
      t.rename :my_political_notebook, :political_notebook

      t.remove :my_last_login_date
      t.remove :my_website
      t.remove :my_congressional_district
    end
  end

  def self.down
    remove_table :user_profiles
    remove_table :user_options

    change_table :user_privacy_options do |t|
      t.rename :name, :my_full_name
      t.rename :email, :my_email
      t.integer :my_last_login_date, :default => 0
      t.rename :zipcode, :my_zip_code
      t.integer :my_website, :default => 0
      t.rename :location, :my_location
      t.rename :profile, :about_me
      t.rename :actions, :my_actions
      t.rename :friends, :my_friends
      t.integer :my_congressional_district, :default => 0
      t.rename :political_notebook, :my_political_notebook
    end
    rename_table :user_privacy_options, :privacy_options
  end
end
