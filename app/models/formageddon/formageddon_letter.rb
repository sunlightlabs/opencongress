# == Schema Information
#
# Table name: formageddon_letters
#
#  id                    :integer          not null, primary key
#  formageddon_thread_id :integer
#  direction             :string(255)
#  status                :text
#  issue_area            :string(255)
#  subject               :text
#  message               :text
#  created_at            :datetime
#  updated_at            :datetime
#  fax_id                :integer
#

# FIXME: This is ugly.
require_dependency File.expand_path(
  'app/models/formageddon/formageddon_letter',
  ActiveSupport::Dependencies.plugins_loader.plugin_paths.select{|p| p =~ /formageddon(-[0-9a-f]+)?$/}.first)

require_dependency 'renders_templates'

class Formageddon::FormageddonLetter
  ##
  # This is a monkeypatch to add faxing capability to formageddon letters
  #
  include RendersTemplates
  include Faxable

  delegate :formageddon_recipient_id,:to => 'Formageddon::FormageddonThread'

  validates_length_of :message, :maximum => 8000, :message => 'Please shorten the body of your message', :allow_blank => true

  PRINT_TEMPLATE = "contact_congress_letters/print"

  def send_letter(options = {})
    recipient = formageddon_thread.formageddon_recipient

    if recipient.nil? or recipient.formageddon_contact_steps.empty?
      unless status =~ /^(SENT|RECEIVED|ERROR)/  # These statuses don't depend on a proper set of contact steps
        self.status = 'ERROR: Recipient not configured for message delivery!'
        self.save
      end
      return false if recipient.nil?
    end

    browser = Mechanize.new
    browser.user_agent_alias = "Windows IE 7"
    browser.follow_meta_refresh = true

    case status
    when 'START', 'RETRY'
      return recipient.execute_contact_steps(browser, self)
    when 'TRYING_CAPTCHA', 'RETRY_STEP'
      attempt = formageddon_delivery_attempts.last

      if status == 'TRYING_CAPTCHA' and ! %w(CAPTCHA_REQUIRED CAPTCHA_WRONG).include? attempt.result
        # weird state, abort
        return false
      end

      browser = (attempt.result == 'CAPTCHA_WRONG') ? attempt.rebuild_browser(browser, 'after') : attempt.rebuild_browser(browser, 'before')

      if options[:captcha_solution]
        @captcha_solution = options[:captcha_solution]
        @captcha_browser_state = attempt.captcha_browser_state
      end

      return recipient.execute_contact_steps(browser, self, attempt.letter_contact_step)
    when /^ERROR:/
      if recipient.fax
        return send_fax :error_msg => status
      end
    end
  end

  def send_fax(options={})
    recipient = options.fetch(:recipient, formageddon_thread.formageddon_recipient)
    if recipient.fax.present?
      if defined? Settings.force_fax_recipient
        send_as_fax(Settings.force_fax_recipient)
      else
        send_as_fax(recipient.fax)
      end
      self.status = "SENT_AS_FAX"
      self.status += ": Error was, #{options[:error_msg]}" if options[:error_msg].present?
      self.save!
      return @fax # TODO: This sucks, why did I do this?
    else
      return false
    end
  end

  def as_html
    @rendered ||= render_to_string(:partial => PRINT_TEMPLATE, :locals => { :letter => self })
  end

  def sender_full_name
    return "#{formageddon_thread.sender_first_name} #{formageddon_thread.sender_last_name}"
  end

  ##
  # Returns the the letter message and stripping away any PII using a regexp.
  # This mmethod is necessary because the contact information for a sender may differ
  # from the user's account information.
  #
  # @return {String} message without any PII
  #
  def message_no_pii
    thread = self.formageddon_thread
    regexp_str = "("
    regexp_str += "(#{sender_full_name})|"     if (thread.sender_first_name && thread.sender_last_name)
    regexp_str += "#{thread.sender_address1}|" if thread.sender_address1
    regexp_str += "#{thread.sender_address2}|" if thread.sender_address2
    regexp_str += "#{thread.sender_city}, |"   if thread.sender_city
    regexp_str += "#{thread.sender_state}|"    if thread.sender_state
    regexp_str += "#{thread.sender_zip5}|"     if thread.sender_zip5
    regexp_str += "#{thread.sender_zip4}|"     if thread.sender_zip4
    regexp_str += "#{thread.sender_phone}|"    if thread.sender_phone
    regexp_str += "#{thread.sender_email}"     if thread.sender_email
    regexp_str += ")"
    return self.message.gsub(/#{regexp_str}/,'')
  end

end
