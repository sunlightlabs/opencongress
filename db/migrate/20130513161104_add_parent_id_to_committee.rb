class AddParentIdToCommittee < ActiveRecord::Migration
  def self.up
    add_column :committees, :parent_id, :integer
  end

  def self.down
    remove_column :committees, :parent_id
  end
end


