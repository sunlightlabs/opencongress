class ContactCongressMailer < ActionMailer::Base
  default :from => "OpenCongress <noreply@opencongress.org>"
  helper :email_congress
  helper :contact_congress_letters
  
  def reply_received_email(ccl, thread)
    @ccl = ccl
    @member_name = "#{thread.formageddon_recipient.title} #{thread.formageddon_recipient.lastname}"
    mail(:to => ccl.user.email, :subject => "#{@member_name} replied to your letter!")
  end 

  def will_not_send_email(options={})
    if options.keys.sort == [:elected_official_name, :message_body, :recipient_email]
      @message = options[:message_body]
      @elected_official_name = options[:elected_official_name]
    else
      raise ArgumentError
    end
    mail(:to => options[:recipient_email], :subject => "Sorry! OpenCongress could not send your message")
  end
end
