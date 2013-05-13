class AddThomasIdToCommittee < ActiveRecord::Migration
  def self.up
    add_column :committees, :thomas_id, :string
    add_index :committees, :thomas_id, :unique => true
  end

  def self.down
    remove_column :committees, :thomas_id
    remove_index :committees, :thomas_id
  end
end
