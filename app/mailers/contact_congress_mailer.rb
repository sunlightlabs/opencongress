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
    if options.keys.sort == [:message_body, :recipient_email, :uncontactable_official]
      @message = options[:message_body]
      @uncontactable_official = options[:uncontactable_official]
    else
      raise ArgumentError
    end
    mail(:to => options[:recipient_email], :subject => "Sorry! OpenCongress could not send your message")
  end

   def will_not_send_email_to_all_myreps(options={})
    if options.keys.sort == [:contactable_officials, :message_body, :recipient_email, :uncontactable_officials]
      @message = options[:message_body]
      @contactable_officials = options[:contactable_officials]
      @uncontactable_officials = options[:uncontactable_officials]
    else
      raise ArgumentError
    end
    mail(:to => options[:recipient_email], :subject => "Sorry! OpenCongress could not send your message to every recipient")
  end 
end
