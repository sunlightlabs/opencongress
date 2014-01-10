class AddLastUserVoteToBill < ActiveRecord::Migration
  def self.up
    add_column :bills, :last_user_vote, :datetime
    congresses = Bill.group(:session).count.keys
    congresses.each do |congress|
      user_votes_by_bill_id = BillVote.includes(:bill).where(:bills => { :session => congress }).group('bills.id').maximum('bill_votes.updated_at')
      user_votes_by_bill_id.each do |bill_id, timestamp|
        bill = Bill.find(bill_id)
        bill.last_user_vote = timestamp
        bill.save!
      end
    end
  end

  def self.down
    remove_column :bills, :last_user_vote
  end
end
