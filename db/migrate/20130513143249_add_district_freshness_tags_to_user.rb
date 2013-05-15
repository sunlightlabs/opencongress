class AddDistrictFreshnessTagsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :district_needs_update, :boolean, :default => false
  end

  def self.down
    remove_column :users, :district_needs_update
  end
end
