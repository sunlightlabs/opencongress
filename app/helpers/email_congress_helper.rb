module EmailCongressHelper
  def email_formatted_names_for(seed)
    seed.allowed_recipients.map do |person|
      %Q[<span class="rep-name" style="color: #000;">#{person.title} #{person.name}</span>].html_safe
    end.to_sentence
  end

  def email_formatted_emails_for(seed, options={:disposition => :allowed})
    seed.send("#{options[:disposition].to_s}_recipient_addresses".to_sym).map do |addr|
      %Q[<a style="color:#96bbcf" href="mailto:#{addr}">#{addr}</a>].html_safe
    end.to_sentence
  end

  def email_formatted_contact_email
    %Q[<a style="color:#96bbcf" href="mailto:#{Settings.contact_us_email}">#{Settings.contact_us_email}</a>].html_safe
  end
end
