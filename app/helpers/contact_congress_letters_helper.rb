module ContactCongressLettersHelper

  def personal_share_message_for_letter(letter, url)
    if letter.contactable_type == 'Bill'
      u("Wrote my members of #Congress on @opencongress to let them know " +
        "#{letter.disposition == 'tracking' ? "I'm tracking" : "I " + letter.disposition} #USbill #" +
        letter.contactable.typenumber.downcase.gsub(/\./, '') + " " + url)
    elsif letter.contactable_type == 'Subject'
      u("Wrote my members of #Congress on @opencongress about #{letter.contactable.term}" + url)
    end
  end

  def generic_share_message_for_letter(letter, url)
    if letter.contactable_type == 'Bill'
      u("A letter to #Congress on @opencongress #{position_clause(letter.disposition)} #USbill #" +
        letter.contactable.typenumber.downcase.gsub(/\./, '') + " " + url)
    elsif letter.contactable_type == 'Subject'
      u("A letter to #Congress on @opencongress regarding #{letter.contactable.term}" + url)
    else
      u("A letter to #Congress on @opencongress: #{letter.subject}")
    end
  end

  def sponsor_tag(bill, person)
    if bill.sponsor == person
      return "(Sponsor)"
    elsif bill.co_sponsors.include?(person)
      return "(Co-Sponsor: Yes)"
    else
      return "(Co-sponsor: No)"
    end
  end

  def formageddon_status_explanation(status)
    if status =~ /SENT(_| )AS(_| )FAX/
      "We have confirmed delivery of your letter via fax. This could mean there was an error with the legislator's contact form, but rest assured&mdash;they got it. Note, though, that this means any replies will come directly to you, and not through OpenCongress.".html_safe
    elsif status =~ /SENT/
      "We have confirmed delivery of your letter."
    elsif status =~ /WARNING/
      "We believe your letter has been sent, but cannot confirm delivery at this time."
    else
      "There was an error sending your letter. We are aware of the error and will retry sending when the error has been fixed."
    end
  end

  def letter_info(letter)
    if letter.direction == 'TO_SENDER'
      "This letter was a reply from the office of #{letter.formageddon_thread.formageddon_recipient} on #{letter.created_at.strftime('%B %d, %Y')}."
    else
      "This letter was sent from #{letter.formageddon_thread.formageddon_sender.login} to #{letter.formageddon_thread.formageddon_recipient} on #{letter.created_at.strftime('%B %d, %Y')}."
    end
  end

  ##
  # Eliminates PII (Personally Identifiable Information)from a congressional letter message
  #
  # @param thread   FormageddonThread object
  # @param message  String to strip the PII from
  #
  def strip_pii_from_message(thread, message)
    regexp_str = ''

    # construct regular expression string by appending together non-blank fields in the thread
    unless (thread.sender_first_name.blank? and thread.sender_last_name.blank?)
      regexp_str += "#{thread.sender_first_name} #{thread.sender_last_name}\|"
    end
    # regexp_str += "#{thread.sender_first_name}\|"                 unless thread.sender_first_name.blank?
    # regexp_str += "#{thread.sender_last_name}\|"                  unless thread.sender_last_name.blank?
    unless thread.sender_address1.blank?
      regexp_str += "#{thread.sender_address1}\|"
      regexp_str += "#{thread.sender_address1.gsub(/(Apt) (\d+)/,'#\2')}\|"
    end
    regexp_str += "#{thread.sender_address2}\|"                   unless thread.sender_address2.blank?
    regexp_str += "#{thread.sender_city.strip}\(,\)*\|"           unless thread.sender_city.blank?
    unless thread.sender_state.blank?
      regexp_str += "(\s+)#{thread.sender_state}(\s+)\|"
      regexp_str += "(\s+)#{State::ABBREVIATIONS_REVERSE["#{thread.sender_state}"]}(\s+)\|"
    end
    regexp_str += "#{thread.sender_zip5}\|"                       unless thread.sender_zip5.blank?
    regexp_str += "#{thread.sender_zip4}\|"                       unless thread.sender_zip4.blank?
    regexp_str += "#{thread.sender_phone.gsub(/[^0-9\s]/,'')}\|"  unless thread.sender_phone.blank?
    regexp_str += "#{thread.sender_email}"                        unless thread.sender_email.blank?

    regexp_str.gsub!(/[^0-9A-Za-z@|,\#\.\-\s+(\()(\))(\|)\*]/, '')
    regexp_str = "(#{regexp_str})"

    puts regexp_str
    return message.gsub(/#{regexp_str}/i,'')
  end

  def privacy_button_classes (letter, button)
    classes = ['button', 'small', 'silver']
    if letter.privacy.upcase == button.to_s.upcase
      classes.push('active')
      classes.push('disabled')
    end
    return classes.join(' ')
  end

  def privacy_button_to (letter, button)
    active = (letter.privacy.downcase.to_sym == button)
    button_html = form_tag(contact_congress_letter_path(letter), :method => :post) do
      [hidden_field_tag(:privacy, button.to_s.upcase),
       submit_tag(button.to_s.capitalize,
                  :disabled => active,
                  :class => privacy_button_classes(letter, button))].join('').html_safe
    end
    wrapper_class = active ? 'active' : ''
    wrapped_button_html = %Q[<div class="#{wrapper_class}">#{button_html}</div>]
    return wrapped_button_html.html_safe
  end

  def body_as_paragraphs (message_body)
    trimmed = message_body.strip
    normalizedLineBreaks = trimmed.gsub(/(\r\n|\n\r)/, "\n")
    normalizedWhitespace = normalizedLineBreaks.gsub(/^\s+$/m, '')
    hasConsecutiveLineBreaks = !normalizedWhitespace.index(/[\r\n]{2,}/).nil?
    lineBreakPattern = hasConsecutiveLineBreaks ? /[\r\n]{2,}/ : /[\r\n]/
    withPTags = normalizedWhitespace.gsub(lineBreakPattern, "\n</p>\n\n<p>\n")
    "<p>\n#{withPTags}\n</p>".html_safe
  end
end
