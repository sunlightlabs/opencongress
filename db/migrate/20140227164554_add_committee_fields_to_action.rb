class AddCommitteeFieldsToAction < ActiveRecord::Migration
  def self.up
    add_column :actions, :in_committee, :text
    add_column :actions, :in_subcommittee, :text
  end

  def self.down
    remove_column :actions, :in_committee
    remove_column :actions, :in_subcommittee
  end
end
