class UserObserver < ActiveRecord::Observer

  def after_create(user)
    UserNotifier.signup_notification(user).deliver if user.should_receive_creation_email?
  end

  def after_save(user)
    UserNotifier.forgot_password(user).deliver if user.recently_forgot_password?
    UserNotifier.reset_password(user).deliver if user.recently_reset_password?
  end

end