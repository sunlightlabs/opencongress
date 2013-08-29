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
    if defined? Settings.force_fax_recipient
      send_as_fax(Settings.force_fax_recipient)
    else
      send_as_fax(recipient.fax)
    end
    self.status = "SENT_AS_FAX"
    self.status += ": Error was, #{options[:error_msg]}" if options[:error_msg].present?
    self.save!
    return @fax
  end

  def as_html
    @rendered ||= render_to_string(:partial => PRINT_TEMPLATE, :locals => { :letter => self })
  end

end
