class UserNotifier < ActionMailer::Base

  default :from => 'noreply@opencongress.org'
  # before_action -> { :setup_email if correct_argument }
  after_action -> { :send_email }

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

  def setup_email(ne)
    an = ne.aggregate_notification
    @user             = an.recipient
    @recipients       = "#{@user.email}"
    @subject          = ''
    @sent_on          = Time.now
    @activity_owner   = an.activity_owner
    @trackables       = an.activities
  end

  private

  def send_email
    # TODO make universal template for notifications
    mail(from: @from, to: @recipients, subject: @subject, template_name: 'template')
  end

  def correct_argument
    if _args.size == 1 and _args[0].is_a?(AggregateNotification)
      @an = _args[0] ; true
    end
    false
  end

end