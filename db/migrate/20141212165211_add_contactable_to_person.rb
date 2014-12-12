class AddContactableToPerson < ActiveRecord::Migration
  def self.up
    add_column :people, :contactable, :boolean, null: false, default: false
  end

  def self.down
    remove_column :people, :contactable
  end
end
