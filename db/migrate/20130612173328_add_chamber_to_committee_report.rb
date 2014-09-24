class AddChamberToCommitteeReport < ActiveRecord::Migration
  def self.up
    add_column :committee_reports, :chamber, :string
    CommitteeReport.where(kind: 'house').update_all(kind: 'hrpt', chamber: 'house')
    CommitteeReport.where(kind: 'senate').update_all(kind: 'srpt', chamber: 'senate')
  end

  def self.down
    remove_column :committee_reports, :chamber
  end
end
