# == Schema Information
#
# Table name: bill_votes
#
#  id         :integer          not null, primary key
#  bill_id    :integer
#  user_id    :integer
#  support    :integer
#  created_at :datetime
#  updated_at :datetime
#

class BillVote < ActiveRecord::Base
  # 1 = opposed, 0 = supported
  belongs_to :user
  belongs_to :bill
  after_save :save_associated_user

  scope :supporting, where(:support => 0)
  scope :opposing, where(:support => 1)

  POSITION_CHOICES = { :support => 0, :oppose => 1 }

  def self.is_valid_user_position (position)
    position = position.to_sym if position.class == String
    if position.class == Symbol
      POSITION_CHOICES.keys.include?(position)
    else
      false
    end
  end

  def self.current_user_position (bill, user)
    # Demote bill and user to their id
    bill_id = (bill.class == Bill) ? bill.id : bill
    user_id = (user.class == User) ? user.id : user
    bv = BillVote.where(:bill_id => bill_id, :user_id => user_id).first
    if bv.nil?
      return nil
    else
      return POSITION_CHOICES.invert[bv.support]
    end
  end

  def self.establish_user_position (bill, user, position)
    # Demote bill and user to their id
    bill_id = (bill.class == Bill) ? bill.id : bill
    user_id = (user.class == User) ? user.id : user

    if POSITION_CHOICES.include?(position)
      bv = BillVote.where(:bill_id => bill_id, :user_id => user_id).first
      if bv.nil?
        bv = BillVote.new(:bill_id => bill_id, :user_id => user_id, :support => nil)
      end

      if bv.support != POSITION_CHOICES[position]
        bv.support = POSITION_CHOICES[position]
        bv.save!
      end
      return bv
    else
      return nil
    end
  end

  private
  def save_associated_user
    # removed solr stuff for now -- June 2012
    #self.user.solr_save
  end
end
