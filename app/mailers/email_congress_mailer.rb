class EmailCongressMailer < ActionMailer::Base
  default :from => "OpenCongress <noreply@opencongress.org>"
  helper :email_congress
  helper :contact_congress_letters

  def must_send_text_version (email)
    @email = email
    mail(:to => email.from_email,
         :subject => "Email Congress could not deliver your message: #{email.subject}")
  end

  def no_recipient_bounce (email)
    @email = email
    mail(:to => email.from_email,
         :subject => "Could not deliver message: #{email.subject}")
  end

  def confirmation (seed, sender_user)
    @seed = seed
    @sender_user = sender_user
    @email = Postmark::Mitt.new(seed.raw_source)
    mail(:to => seed.sender_email,
         :subject => "Please confirm your message to Congress: #{seed.email_subject}")
  end

  def complete_profile (seed, profile)
    @profile = profile
    @seed = seed
    @email = Postmark::Mitt.new(seed.raw_source)
    mail(:to => seed.sender_email,
         :subject => "Please complete your message to Congress: #{seed.email_subject}")
  end
end
