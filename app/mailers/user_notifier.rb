class UserNotifier < ActionMailer::Base

  default :from => 'noreply@opencongress.org'
  before_action :setup_email
  after_action :send_email

  def signup_notification(user)
    @subject    += 'Confirm Your OpenCongress Login'
    @body[:url]  = "#{Settings.base_url}account/activate/#{user.activation_code}"
  end

  def activation(user)
    @subject    += 'Your account has been activated!'
    @body[:url]  = Settings.base_url
  end

  def forgot_password(user)
    @subject    += 'Request to change your password'
    @body[:url]  = "#{Settings.base_url}account/reset_password/#{user.password_reset_code}"
  end

  def reset_password(user)
    @subject    += 'Your password has been set'
  end

  def comment_warning(user, comment)
    @from = "\"OpenCongress Editors\" <oc-mail@sunlightfoundation.com>"
    @subject += "Warning from OpenCongress re: your comment"
    @body[:comment] = comment
  end

  def friend_invite_notification(notification)
    @from = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @subject    += "#{CGI::escapeHTML(notification.activity.owner.login)} invites you to be Friends on OpenCongress"
    @body[:friend] = notification.activity.trackable
  end

  def friend_broken_notification(notification)
    @from = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @subject  += "#{CGI::escapeHTML(notification.activity.owner.login)} has ended your OpenCongress Friendship"
    @friend = notification.activity.trackable
  end

  def friend_confirmed_notification(notification)
    @from = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @subject  += "#{CGI::escapeHTML(notification.activity.owner.login)} has accepted your Friend invitation on OpenCongress!"
    @friend = notification.activity.trackable
  end

  def bill_action_create_notification(notification)
    @from = "\"OpenCongress Notification\" <notification@opencongress.org>"
    @subject  += "#{CGI::escapeHTML(notification.activity.owner.title_full_common)} has received an action!"
    @user = notification.recipient
    @bill_action = notification.activity.trackable
  end

  protected

  def setup_email
    @recipients  = "#{get_recipient.email}"
    @subject     = ''
    @sent_on     = Time.now
    @user        = get_notification.recipient
    @trackable   = get_notification.activity.trackable
  end

  private

  def send_email
    mail(from: @from, to: @recipients, subject: @subject)
  end

  def get_notification
    _args[0].is_a?(Notification) ? _args[0] : raise TypeError
  end

  def get_recipient
      get_notification.recipient
  end

end