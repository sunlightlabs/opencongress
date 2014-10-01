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

  #========== CALLBACKS

  after_update -> (friend) { confirm_friendship(friend) if friend.confirmed_changed? and friend.confirmed? }
  # after_create -> (friend) { }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :user
  belongs_to :friend, :class_name => 'User', :foreign_key => 'friend_id'

  #=========== ACCESSORS

  attr_accessible :user_id, :friend_id, :confirmed, :confirmed_at

  #tracked owner: :user, recipient: :friend

  def confirm!
    @confirmed = true
    now = Time.new
    update_attributes!({:confirmed => true, :confirmed_at => now})
    Friend.create({:friend_id => self.user_id, :user_id => self.friend_id, :confirmed => true, :confirmed_at => now})
    self.create_activity :confirm, owner: :friend, recipient: :user
  end

  def confirmed?
    self.confirmed
  end

  def send_email_notification(friend)
    UserNotifier.friend_notification(friend).deliver unless friend.confirmed == true
  end


  def recently_confirmed?
    @confirmed
  end
  
  def self.recent_activity(friends)
    ra = []
    number_of_friends = friends.length
    range = [0..3]
    case number_of_friends
    when 1
      friends.each do |f|
        ra.concat(f.friend.recent_public_actions(12)[0..11])
      end
    when 2
      friends.each do |f|
        ra.concat(f.friend.recent_public_actions(6)[0..5])
      end
    else
      friends.each do |f|
        ra.concat(f.friend.recent_public_actions(4)[0..3])
      end
    end

    ra.compact.sort_by{|p| p.created_at}.reverse
  end

  def self.create_confirmed_friendship(u1, u2)
    Friend.create({:friend_id => u1.id, :user_id => u2.id, :confirmed => true, :confirmed_at => Time.new})
    Friend.create({:friend_id => u2.id, :user_id => u1.id, :confirmed => true, :confirmed_at => Time.new})
  end

  private

  def confirm_friendship(friend)
    if Friend.where(friend: friend.user, user: friend.friend).empty?
      reciprocate = Friend.create({:friend_id => friend.user_id,
                     :user_id => friend.friend_id,
                     :confirmed => true,
                     :confirmed_at => Time.new})
      reciprocate.create_activity :confirmed, owner: friend.friend, recipient: friend.user
    end


    # if friend.
    # if friend.recently_confirmed?
    # UserNotifier.friend_confirmed_notification(friend).deliver
    # Friend.create({:friend_id => friend.user_id, :user_id => friend.friend_id, :confirmed => true, :confirmed_at => Time.new}) unless Friend.find_by_friend_id_and_user_id(friend.user_id, friend.friend_id)
    #end
  end


end
