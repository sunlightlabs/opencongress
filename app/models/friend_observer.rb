class FriendObserver < ActiveRecord::Observer

  def after_create(friend)
    # UserNotifier.friend_notification(friend).deliver unless friend.confirmed == true
  end

  def after_save(friend)
    #if friend.recently_confirmed?
      # UserNotifier.friend_confirmed_notification(friend).deliver
      #Friend.create({:friend_id => friend.user_id, :user_id => friend.friend_id, :confirmed => true, :confirmed_at => Time.new}) unless Friend.find_by_friend_id_and_user_id(friend.user_id, friend.friend_id)
    #end
  end
end

