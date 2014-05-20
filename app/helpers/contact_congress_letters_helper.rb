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

  def opposite_privacy (letter)
    if letter.privacy == 'PRIVATE'
      'PUBLIC'
    elsif letter.privacy == 'PUBLIC'
      'PRIVATE'
    else
      raise "Invalid privacy setting for letter #{letter.id}: #{letter.privacy}"
    end
  end

  def privacy_button_classes (letter, button)
    classes = ['btn', 'pull-left']
    if letter.privacy.upcase == button.to_s.upcase
      classes.push('active')
      classes.push('disabled')
    end
    return classes.join(' ')
  end

  def body_as_paragraphs (letter)
    trimmed = letter.message.strip
    normalizedLineBreaks = trimmed.gsub(/(\r\n|\n\r)/, "\n")
    normalizedWhitespace = normalizedLineBreaks.gsub(/^\s+$/m, '')
    hasConsecutiveLineBreaks = !normalizedWhitespace.index(/[\r\n]{2,}/).nil?
    if hasConsecutiveLineBreaks == true
      lineBreakPattern = /[\r\n]{2,}/
    else
      lineBreakPattern = /[\r\n]/
    end
    withPTags = normalizedWhitespace.gsub(lineBreakPattern, "\n</p>\n\n<p>\n")
    "<p>\n#{withPTags}\n</p>".html_safe
  end
end
