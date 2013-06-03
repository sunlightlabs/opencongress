class AddThomasIdToCommittee < ActiveRecord::Migration
  def self.up
    add_column :committees, :thomas_id, :string
  end

  def self.down
    remove_column :committees, :thomas_id
  end
end
