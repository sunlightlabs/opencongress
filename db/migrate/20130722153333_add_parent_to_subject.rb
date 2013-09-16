class AddParentToSubject < ActiveRecord::Migration
  def self.up
    add_column :subjects, :parent_id, :integer
  end

  def self.down
    remove_column :subjects, :parent_id
  end
end
