class SetDefaultValuePageViewCount < ActiveRecord::Migration

  def self.up
    change_column :people, :page_views_count, :integer, :default => 0
    change_column :bills, :page_views_count, :integer, :default => 0
    change_column :subjects, :page_views_count, :integer, :default => 0
    change_column :committees, :page_views_count, :integer, :default => 0
  end

  def self.down
    change_column :people, :page_views_count, :integer, :default => nil
    change_column :bills, :page_views_count, :integer, :default => nil
    change_column :subjects, :page_views_count, :integer, :default => nil
    change_column :committees, :page_views_count, :integer, :default => nil
  end

end