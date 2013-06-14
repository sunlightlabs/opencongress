class AddChamberToCommitteeReport < ActiveRecord::Migration
  def self.up
    add_column :committee_reports, :chamber, :string
    CommitteeReport.update_all "kind = 'hrpt', chamber = 'house'",
                               "kind = 'house'"
    CommitteeReport.update_all "kind = 'srpt', chamber = 'senate'",
                               "kind = 'senate'"
  end

  def self.down
    remove_column :committee_reports, :chamber
  end
end
