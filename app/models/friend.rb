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
  include PrivacyObject

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

  # Create a confirmed friendship (both input users follow one another)
  #
  # @param u1 [User] user to follow second user and be followed
  # @param u2 [User] user to follow first user and be followed
  def self.create_confirmed_friendship(u1, u2)
    Friend.create({:friend_id => u1.id, :user_id => u2.id, :confirmed => true, :confirmed_at => Time.new})
    Friend.create({:friend_id => u2.id, :user_id => u1.id, :confirmed => true, :confirmed_at => Time.new})
  end

  # Retrieves the recent activity for a list of friends
  #
  # @param friends [Array, Relation] list of friends
  # @return [Relation<PublicActivity::Activity>] recent activity of friends
  def self.recent_activity(friends, timeframe=7.days)
    ra = []
    number_of_friends = friends.length
    case number_of_friends
      when 1
        friends.each {|f| ra.concat(f.friend.recent_activity(12, timeframe)) }
      when 2
        friends.each {|f| ra.concat(f.friend.recent_public_actions(6, timeframe)) }
      else
        friends.each {|f| ra.concat(f.friend.recent_public_actions(4, timeframe)) }
    end
    ra.compact.sort_by{|p| p.created_at}.reverse
  end

  # Checks to see if both user arguments are confirmed friends
  #
  # @param u1 [User] user 1
  # @param u2 [User] user 2
  # @return [Boolean] true if both users are confirmed friends, false otherwise
  def self.are_confirmed_friends?(u1, u2)
    Friend.where(user_id: u1.id, friend_id: u2.id, confirmed: true).any? and
        Friend.where(user_id: u2.id, friend_id: u1.id, confirmed: true).any?
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
    i_f = inverse_friend
    i_f.update_attributes!({:confirmed => false, :confirmed_at => nil}) if i_f.present?
    self.destroy
  end

  # Gets the inverse friendship for this friendship instance
  #
  # @return [Friend, nil] the inverse friend of this friends or nil if it doesn't exist
  def inverse_friend
    confirmed? ? Friend.where(user: self.friend, friend: self.user).first : nil
  end

end