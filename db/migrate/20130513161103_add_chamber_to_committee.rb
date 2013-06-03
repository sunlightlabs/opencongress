class AddChamberToCommittee < ActiveRecord::Migration
  def self.up
    add_column :committees, :chamber, :string
  end

  def self.down
    remove_column :committees, :chamber
  end
end

