class UserObserver < ActiveRecord::Observer
  def after_create(user)
    UserNotifier.signup_notification(user).deliver unless user.facebook_connect_user?
  end

  def after_save(user)
    UserNotifier.activation(user).deliver if user.recently_activated?
    UserNotifier.forgot_password(user).deliver if user.recently_forgot_password?
    UserNotifier.reset_password(user).deliver if user.recently_reset_password?
  end
end
