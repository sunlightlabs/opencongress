# == Schema Information
#
# Table name: friends
#
#  id           :integer          not null, primary key
#  user_id      :integer
#  friend_id    :integer
#  confirmed    :boolean
#  created_at   :datetime
#  updated_at   :datetime
#  confirmed_at :datetime
#

class Friend < OpenCongressModel

  #========== INCLUDES

  include PublicActivity::Model

  #========== FILTERS

  after_create   -> { create_activity(:follow, owner: :user, recipient: :friend) unless confirmed? }
  before_destroy -> { create_activity(:unfollow, owner: :user, recipient: :friend) }

  #========== RELATIONS

  #----- BELONGS TO

  belongs_to :user
  belongs_to :friend, :class_name => 'User', :foreign_key => 'friend_id'

  #========== ALIASES

  alias_attribute :confirmed?, :confirmed

  #========== METHODS

  #----- CLASS

  def self.create_confirmed_friendship(u1, u2)
    Friend.create({:friend_id => u1.id, :user_id => u2.id, :confirmed => true, :confirmed_at => Time.new})
    Friend.create({:friend_id => u2.id, :user_id => u1.id, :confirmed => true, :confirmed_at => Time.new})
  end

  def self.recent_activity(friends)
    ra = []
    number_of_friends = friends.length
    range = [0..3]
    case number_of_friends
      when 1
        friends.each {|f| ra.concat(f.friend.recent_public_actions(12)[0..11]) }
      when 2
        friends.each {|f| ra.concat(f.friend.recent_public_actions(6)[0..5]) }
      else
        friends.each {|f| ra.concat(f.friend.recent_public_actions(4)[0..3]) }
    end

    ra.compact.sort_by{|p| p.created_at}.reverse
  end

  #----- INSTANCE

  public

  def confirm!
    if not confirmed? and Friend.where(friend: self.user, user: self.friend).empty?
      now = Time.new
      self.update_attributes!({:confirmed => true, :confirmed_at => now})
      reciprocate = Friend.create({:friend => self.user, :user => self.friend, :confirmed => true, :confirmed_at => now})
      reciprocate.create_activity(:confirmed, owner => :user, recipient => :friend)
    else
      false
    end
  end

  def defriend
    if inverse_friend.present?
      self.inverse_friend.update_attributes!({:confirmed => false, :confirmed_at => nil})
    end
    self.destroy
  end

  # Gets the inverse friendship for this friendship instance
  #
  # @return [Friend, nil] the inverse friend of this friends or nil if it doesn't exist
  def inverse_friend
    confirmed? ? Friend.where(user: self.friend, friend: self.user).first : nil
  end

end