module EmailCongressHelper

  def at_email_congress (localpart)
    "#{localpart}@#{Settings.email_congress_domain}"
  end

  def incoming_email (options=Hash.new)
    default_email = {
      "Date" => "Fri, 2 May 2014 16:29:46 -0400",
      "From" => "user@example.com",
      "FromFull" => {
        "Email" => "user@example.com",
        "Name" => "John Doe"
      },
      "FromName" => "John Doe",
      "Headers" => [],
      "HtmlBody" => "(empty body)",
      "MailboxHash" => "",
      "MessageID" => "8edcca77-08b8-4c6f-b3a6-5497c4d6bf5d",
      "ReplyTo" => "",
      "Subject" => "(no subject)",
      "Tag" => "",
      "TextBody" => "(empty body)",
      "To" => "Sen.Brown@inbound.postmarkapp.com",
      "ToFull" => [
        {
          "Email" => "sen.brown@inbound.postmarkapp.com",
          "Name" => ""
        }
      ]
    }
    default_email.merge(options)
  end

  def incoming_seed (options=Hash.new)
    EmailCongress.seed_for_postmark_object(incoming_email(options))
  end

end