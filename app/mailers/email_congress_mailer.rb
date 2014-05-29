class EmailCongressMailer < ActionMailer::Base
  default :from => "noreply@opencongress.org"
  helper :email_congress

  def html_body_alert (email)
    @email = email
    mail(:to => Settings.contact_us_email,
         :subject => "EmailCongress message has only HTML body: #{email.subject}")
  end

  def no_recipient_bounce (email)
    @email = email
    mail(:to => email.from_email,
         :subject => "Could not deliver message: #{email.subject}")
  end

  def confirmation (seed)
    @seed = seed
    @email = Postmark::Mitt.new(seed.raw_source)
    mail(:to => seed.sender_email,
         :subject => "Please confirm your EmailCongress message: #{seed.email_subject}")
  end

  def complete_profile (seed, profile)
    @profile = profile
    @seed = seed
    @email = Postmark::Mitt.new(seed.raw_source)
    mail(:to => seed.sender_email,
         :subject => "Please complete your EmailCongress message: #{seed.email_subject}")
  end
end
