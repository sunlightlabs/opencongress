class RemoveDefaultFromBillVotes < ActiveRecord::Migration
  def self.up
    change_column_default :bill_votes, :support, nil
  end

  def self.down
    change_column_default :bill_votes, :support, 0
  end
end
