class UserNotifier < ActionMailer::Base

  default :from => "noreply@opencongress.org"
  after_action :send_mail

  def signup_notification(user)
    setup_email(user)
    @subject    += 'Confirm Your OpenCongress Login'
    @body[:url]  = "#{Settings.base_url}account/activate/#{user.activation_code}"
  end

  def activation(user)
    setup_email(user)
    @subject    += 'Your account has been activated!'
    @body[:url]  = Settings.base_url
  end

  def forgot_password(user)
    setup_email(user)
    @subject    += 'Request to change your password'
    @body[:url]  = "#{Settings.base_url}account/reset_password/#{user.password_reset_code}"
  end

  def reset_password(user)
    setup_email(user)
    @subject    += 'Your password has been set'
  end

  def comment_warning(user, comment)
    setup_email(user)
    @from = "\"OpenCongress Editors\" <oc-mail@sunlightfoundation.com>"
    @subject += "Warning from OpenCongress re: your comment"
    @body[:comment] = comment
  end

  def friend_invite_notification(notification)
    setup_email(notification.recipient)
    @from = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @subject    += "#{CGI::escapeHTML(notification.activity.owner.login)} invites you to be Friends on OpenCongress"
    @body[:friend] = notification.activity.trackable
  end

  def friend_broken_notification(notification)
    setup_email(notification.recipient)
    @from = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @subject  += "#{CGI::escapeHTML(notification.activity.owner.login)} has ended your OpenCongress Friendship"
    @friend = notification.activity.trackable
  end

  def friend_confirmed_notification(notification)
    setup_email(notification.recipient)
    @from = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @subject  += "#{CGI::escapeHTML(notification.activity.owner.login)} has accepted your Friend invitation on OpenCongress!"
    @friend = notification.activity.trackable
  end

  def bill_action_create_notification(notification)
    setup_email(notification.recipient)
    @from = "\"OpenCongress Notification\" <notification@opencongress.org>"
    @subject  += "#{CGI::escapeHTML(notification.activity.owner.title_full_common)} has received an action!"
    @user = notification.recipient
    @bill_action = notification.activity.trackable
  end

  protected

  def setup_email(user)
    @recipients  = "#{user.email}"
    @subject     = ''
    @sent_on     = Time.now
  end

  private

  def send_mail
    mail(from: @from, to: @recipients, subject: @subject)
  end

end