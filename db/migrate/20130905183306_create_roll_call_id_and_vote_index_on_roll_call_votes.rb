class CreateRollCallIdAndVoteIndexOnRollCallVotes < ActiveRecord::Migration
  def self.up
    # add_index :roll_call_votes, [:roll_call_id, :vote]
  end

  def self.down
    # remove_index :roll_call_votes, [:roll_call_id, :vote]
  end
end
