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

class BillVote < OpenCongressModel

  #========== INCLUDES

  include PrivacyObject

  #========== CONSTANTS

  POSITION_CHOICES = { :support => 0, :oppose => 1 }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :user
  belongs_to :bill

  #========== SCOPES

  scope :supporting, -> { where(:support => 0) }
  scope :opposing, -> { where(:support => 1) }

  #========== METHODS

  #----- CLASS

  def self.is_valid_user_position (position)
    position = position.to_sym if position.class == String
    position.class == Symbol ? POSITION_CHOICES.keys.include?(position) : false
  end

  def self.current_user_position (bill, user)
    # Demote bill and user to their id
    bill_id = (bill.class == Bill) ? bill.id : bill
    user_id = (user.class == User) ? user.id : user
    bv = BillVote.where(:bill_id => bill_id, :user_id => user_id).first
    bv.nil? ? nil : POSITION_CHOICES.invert[bv.support]
  end

  def self.establish_user_position (bill, user, position)
    # Demote bill and user to their id
    bill_id = (bill.class == Bill) ? bill.id : bill
    user_id = (user.class == User) ? user.id : user

    if POSITION_CHOICES.include?(position)
      bv = BillVote.where(:bill_id => bill_id, :user_id => user_id).first
      bv = BillVote.new(:bill_id => bill_id, :user_id => user_id, :support => nil) if bv.nil?
      bv.update_attributes(support: POSITION_CHOICES[position]) if bv.support != POSITION_CHOICES[position]
      return bv
    else
      return nil
    end
  end

end