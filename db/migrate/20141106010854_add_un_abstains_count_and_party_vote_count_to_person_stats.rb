class AddUnAbstainsCountAndPartyVoteCountToPersonStats < ActiveRecord::Migration
  def self.up
    change_table :person_stats do |t|
      t.integer :unabstains
      t.integer :unabstains_rank
      t.integer :party_votes_count
    end
  end

  def self.down
    change_table :person_stats do |t|
      t.remove :unabstains
      t.remove :unabstains_rank
      t.remove :party_votes_count
    end
  end
end
