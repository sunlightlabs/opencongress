class NotificationMailer < ActionMailer::Base

  default from: 'noreply@opencongress.org'

  def setup_email(no)

    @distributors     = no.notification_distributors

    @user             = no.user
    @recipients       = "#{@user.email}"

    @subject        = @distributors.count == 1 ?
                      "#{@distributors.first.notification_aggregate.activity_owner.to_email_subject} has received updates on OpenCongress!" :
                      "You have #{@distributors.count.to_s} new notifications on OpenCongress!"

    @sent_on          = Time.now

    mail(to: @recipients, subject: @subject, template_name: 'template')
  end

end