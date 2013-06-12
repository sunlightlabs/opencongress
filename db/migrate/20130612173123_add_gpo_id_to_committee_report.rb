class AddGpoIdToCommitteeReport < ActiveRecord::Migration
  def self.up
    add_column :committee_reports, :gpo_id, :string
  end

  def self.down
    remove_column :committee_reports, :gpo_id
  end
end
