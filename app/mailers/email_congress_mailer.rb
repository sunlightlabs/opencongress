class EmailCongressMailer < ActionMailer::Base
  default :from => "noreply@opencongress.org"

  def html_body_alert (seed)
    @email = Postmark::Mitt.new(seed.raw_source)
    mail(:to => Settings.contact_us_email,
         :subject => "EmailCongress message has only HTML body: #{seed.email_subject}")
  end

  def no_recipient_bounce (seed, rejected_addresses, unresolvable_addresses)
    @unresolvable_addresses = unresolvable_addresses
    @rejected_addresses = rejected_addresses
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
