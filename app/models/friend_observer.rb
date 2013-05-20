class FriendObserver < ActiveRecord::Observer

  def after_create(friend)
    UserNotifier.friend_notification(friend).deliver unless friend.confirmed == true
  end

  def before_destroy(friend)
   unless @reciprical_flag
    UserNotifier.friend_rejected_notification(friend).deliver if friend.confirmed == false
    UserNotifier.friendship_broken_notification(friend).deliver if friend.confirmed == true
    reciprical = Friend.find_by_friend_id_and_user_id(friend.user_id, friend.friend_id)
    UserNotifier.friendship_broken_notification(reciprical).deliver if friend.confirmed == true
#    UserNotifier.friend_rejected_notification(reciprical).deliver if friend.confirmed == false
    @reciprical_flag = true
    reciprical.destroy if reciprical
   end
  end

  def after_save(friend)
    if friend.recently_confirmed?
      UserNotifier.friend_confirmed_notification(friend).deliver
      Friend.create({:friend_id => friend.user_id, :user_id => friend.friend_id, :confirmed => true, :confirmed_at => Time.new}) unless Friend.find_by_friend_id_and_user_id(friend.user_id, friend.friend_id)
    end
  end
end

