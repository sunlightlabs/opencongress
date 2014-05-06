##
# This migration drops the old legacy columns from User.
#
# Code to deal with delegation of methods to the new models must be present when this migration is run.
#
class PruneFieldsFromUser < ActiveRecord::Migration
  def self.up
    change_table :users do |t|
      t.remove :accept_terms
      t.remove :show_email
      t.remove :show_homepage
      t.remove :location
      t.remove :subscribed
      t.remove :chat_aim
      t.remove :chat_yahoo
      t.remove :chat_msn
      t.remove :chat_icq
      t.remove :chat_gtalk
      t.remove :show_aim
      t.remove :show_full_name
      t.remove :enabled

      t.remove :full_name
      t.remove :homepage
      t.remove :about
      t.remove :main_picture
      t.remove :small_picture
      t.remove :zipcode
      t.remove :zip_four
      t.remove :default_filter
      t.remove :mailing
      t.remove :partner_mailing
      t.remove :feed_key

      t.remove :state_cache
      t.remove :district_cache
      t.remove :admin
      t.remove :blog_author
    end
  end
  def self.down
    change_table :users do |t|
      t.boolean :accept_terms, :default => false
      t.boolean :show_email, :default => false
      t.boolean :show_homepage, :default => false
      t.string  :location
      t.boolean :subscribed, :default => false
      t.string  :chat_aim
      t.string  :chat_yahoo
      t.string  :chat_msn
      t.string  :chat_icq
      t.string  :gtalk
      t.boolean :show_aim, :default => false
      t.boolean :show_full_name, :default => false
      t.boolean :enabled, :default => true

      t.string  :full_name
      t.string  :homepage
      t.text    :about
      t.string  :main_picture
      t.string  :small_picture
      t.string  :zipcode, :limit => 5
      t.string  :zip_four, :limit => 4
      t.integer :default_filter, :default => 5
      t.boolean :mailing, :default => true
      t.boolean :partner_mailing, :default => false
      t.string  :feed_key

      t.boolean :admin, :default => false
      t.boolean :blog_author, :default => false
      t.text :district_cache
      t.text :state_cache
    end
  end
end
