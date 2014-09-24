class AddIsMajorToBill < ActiveRecord::Migration
  def self.up
    add_column :bills, :is_major, :boolean
    Bill.where('hot_bill_category_id IS NOT NULL').update_all(is_major: true)
  end

  def self.down
    remove_column :bills, :is_major
  end
end
