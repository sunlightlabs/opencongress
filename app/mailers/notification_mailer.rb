class NotificationMailer < ActionMailer::Base

  layout 'notification_email'
  default from: 'noreply@opencongress.org'

  def setup_email(no)

    @distributors     = no.notification_distributors

    @user             = no.user
    @recipients       = "#{@user.email}"

    @subject        = 'You have new notifications on OpenCongress!' #@distributors.count == 1 ?
                      #"#{@distributors.first.notification_aggregate.activity_owner.to_email_subject} has received updates on OpenCongress!" :
                      #"You have #{@distributors.count.to_s} new notifications on OpenCongress!"

    @sent_on          = Time.now

    mail(to: @recipients,
         subject: @subject,
         template_path: 'notifications',
         template_name: 'email_base')


  #  mail(to: @recipients, subject: @subject) do |format|
  #    format.html { render layout: Rails.root + '/app/views/notifications/email/frame' }
  #    format.text { render layout: Rails.root + '/app/views/notifications/email/frame' }
  #  end


    #mail(to: @recipients, subject: @subject, template_name: 'template')
  end

end