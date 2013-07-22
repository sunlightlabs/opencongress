class AddIsMajorToBill < ActiveRecord::Migration
  def self.up
    add_column :bills, :is_major, :boolean
    Bill.update_all "is_major = true", "hot_bill_category_id IS NOT NULL"
  end

  def self.down
    remove_column :bills, :is_major
  end
end
