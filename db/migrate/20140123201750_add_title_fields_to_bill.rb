class AddTitleFieldsToBill < ActiveRecord::Migration
  def self.up
    add_column :bills, :short_title, :text
    add_column :bills, :popular_title, :text
    add_column :bills, :official_title, :text
    add_column :bills, :manual_title, :text
  end

  def self.down
    remove_column :bills, :short_title
    remove_column :bills, :popular_title
    remove_column :bills, :official_title
    remove_column :bills, :manual_title
  end
end
