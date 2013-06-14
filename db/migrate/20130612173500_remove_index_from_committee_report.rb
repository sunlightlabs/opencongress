class RemoveIndexFromCommitteeReport < ActiveRecord::Migration
  def self.up
    remove_column :committee_reports, :index
  end

  def self.down
    add_column :committee_reports, :index, :integer
  end
end
