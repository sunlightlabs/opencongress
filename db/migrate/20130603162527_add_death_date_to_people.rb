class AddDeathDateToPeople < ActiveRecord::Migration
  def self.up
    add_column :people, :death_date, :date
  end

  def self.down
    remove_column :people, :death_date
  end
end
