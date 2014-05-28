require_dependency 'email_congress'
class EmailCongressController < ApplicationController
  skip_before_filter :protect_from_forgery, :only => [:complete_profile]
  skip_before_filter :pending_email_seed_prompt

  # User gets confirmation link or form requesting sender details.

  # Confirmation of email is done via nonce.

  # Users are only able to email their own representatives.

  # All details for a message are stored on an EmailCongressLetterSeed model
  # until it is converted to a FormageddonThread and then disposed of.

  before_filter :login_required, :only => [:discard]
  before_filter :decode_email, :only => [:message_to_members]
  before_filter :find_by_confirmation_code, :only => [:confirm, :complete_profile, :confirmed, :discard]
  before_filter :only_resolved, :only => [:confirmed]
  before_filter :only_unresolved, :only => [:confirm, :complete_profile, :discard]
  before_filter :find_user, :only => [:message_to_members, :confirm, :complete_profile, :discard]
  before_filter :logout_if_necessary, :only => [:confirm, :complete_profile]
  before_filter :lookup_recipients, :only => [:message_to_members, :confirm, :confirmed]
  before_filter :restrict_recipients, :only => [:message_to_members, :confirm, :confirmed]

  def debug
    puts "=================="
    puts "PARAMS:"
    puts params.to_s
    puts "REQUEST BODY:"
    puts request.body.read.to_s
    puts "=================="
    head :ok
  end

  def message_to_members
    # Spawns a EmailCongressLetter model and sends a verification email.
    # Potention error conditions:
    #   New user
    #   User is not activated
    #   User is trying to email a nonexistent address
    #   User is trying to email someone they are not allowed to email

    if @recipient_addresses.empty?
      EmailCongressMailer.no_recipient_bounce(@email, @rejected_addresses, @unresolvable_addresses).deliver
      return head :ok
    end

    if @email.text_body.blank? && !@email.html_body.blank?
      EmailCongressMailer.html_body_alert(@email).deliver
      return head :ok
    end

    seed = EmailCongress.seed_for_postmark_object(@email)

    @profile = EmailCongress::ProfileProxy.new(seed)
    if @sender_user
      @profile = @profile.merge(EmailCongress::ProfileProxy.new(@sender_user))
    end

    if @sender_user && @profile.valid?
      EmailCongressMailer.confirmation(seed).deliver
    else
      EmailCongressMailer.complete_profile(seed, @profile).deliver
    end
    head :ok
  end

  def confirm
    # Completes the seed -> letter conversion.

    @profile = EmailCongress::ProfileProxy.new(@seed)
    if @sender_user
      user_profile = EmailCongress::ProfileProxy.build(@sender_user.user_profile, @sender_user)
      @profile = @profile.merge(user_profile)
    end

    if !@profile.valid? || !@sender_user
      # Users who send a message from an unknown address will be directed to
      # :complete_profile in response to their initial email. If they change
      # their email address between the time of the initial email and when they
      # clicked the confirmation link, they would end up here due to the
      # !@sender_user condition.
      if @sender_user
        flash[:error] = @profile.errors.full_messages.to_sentence
      else
        flash[:error] = "To send your message we need to collect the information below."
      end
      return redirect_to(:action => :complete_profile,
                         :confirmation_code => @seed.confirmation_code)
    end

    # We have a user and a complete profile.
    begin
      if @sender_user.user_profile.zip_four.blank?
        # Some congress members require the zip_four but we don't include it in
        # the profile form.
        ZipInferrenceService.new(@sender_user.user_profile)
      end
      @profile.copy_to(@seed)
      recipients = @recipients_by_address.map{ |addr, rcpt| rcpt }.compact
      cc_letter = EmailCongress.reify_for_contact_congress(@sender_user, @seed, recipients)
      cc_letter.formageddon_threads.each do |thread|
        letter = thread.formageddon_letters.first
        if letter
          letter.delay.send_letter
        end
      end
      @seed.confirm!
      return redirect_to(:action => :confirmed, :confirmation_code => @seed.confirmation_code)
    rescue => e
      # TODO: Write job to find these seeds and retry them.
      Raven.capture_exception(e)
      flash[:error] = "Your letter could not be sent due to technical difficulties. Please try again later."
      return redirect_to(:action => :complete_profile, :confirmation_code => @seed.confirmation_code)
    end
  end

  def confirmed
    # TODO: The template should warn about illegitamate recipients
    if logged_in?
      @prompt_for_password = current_user.previous_login_date.nil?
      @prompt_for_email = current_user.email != @seed.sender_email
    else
      @prompt_for_password = false
      @prompt_for_email = false
    end
  end

  def complete_profile
    @profile = EmailCongress::ProfileProxy.build(@seed)

    if request.method_symbol == :post
      if params[:profile]
        params[:profile].delete(:email)
        params[:profile][:accept_tos] = (params[:profile][:accept_tos] == 'true') || @sender_user.accepted_tos?
        @params_profile = EmailCongress::ProfileProxy.new(OpenStruct.new(params[:profile]))
        @profile = @params_profile.merge(@profile) # Values from the form should override existing values
      end

      if @profile.valid?
        if !@sender_user
          @sender_user = User.generate_for_profile(@profile)
          @sender_user.activate!
          self.current_user = @sender_user
        else
          @profile.copy_to(@sender_user)
          @profile.copy_to(@sender_user.user_profile)
          @sender_user.save!
        end

        if @sender_user
          @profile.copy_to(@seed)
          @seed.save!
          return redirect_to(:action => :confirm, :confirmation_code => @seed.confirmation_code)
        else
          @profile.errors.add(:account, "could not be created due to technical difficulties")
        end
      end
    elsif request.method_symbol == :get
      if @sender_user
        @profile = @profile.merge_many(@sender_user.user_profile, @sender_user)
      end
    end
  end

  def discard
    unless request.method_symbol == :post
      return render_404
    end

    unless @sender_user == current_user
      return redirect_to(:controller => :index, :action => :index)
    end

    @seed.resolved = true
    @seed.resolution = 'discarded by user'
    @seed.resolved_at = Time.zone.now
    @seed.save!

    flash[:notice] = "Discarded email re: #{@seed.email_subject}"
    return redirect_to(:controller => :profile, :action => :actions, :login => current_user.login)
  end

  ### TODO: mark private when done
  def decode_email
    request_body = request.body.read
    @email_obj = JSON.load(request_body)
    begin
      @email = Postmark::Mitt.new(request_body)
    rescue
      head :bad_request
    end
  end

  def find_user
    @sender_user = User.find_by_email(@email.from_email)
  end

  def logout_if_necessary
    # If the browser is logged in and the seed associated with the confirmation
    # code has an email address that does not match the logged in user, the
    # browser should be logged out and then the confirmation process should
    # proceed to link the seed and the user that share an email address.

    if @sender_user && logged_in? && @sender_user != current_user
      return logout_current_user_and_return
    end

    if !@sender_user && logged_in?
      # We don't have a user associated with the email address but we do have a
      # user logged in. We want to give them the chance to associate their
      # account with this email address.
      @sender_user = current_user
    end
  end

  def lookup_recipients
    # This expands any special recipient aliases and resolves each address to a
    # Person model, keeping a list of the nonexistent ones.
    @recipient_addresses = @email_obj.values_at("ToFull", "CcFull", "BccFull").flatten.compact.map{|o| o["Email"]}.uniq
    @recipient_addresses = EmailCongress.expand_special_addresses(@sender_user, @recipient_addresses)
    @recipients_by_address = Hash.new
    @recipient_addresses.each do |addr|
      begin
        @recipients_by_address[addr] = EmailCongress.congressmember_for_address(addr)
      rescue
        @recipients_by_address[addr] = nil
      end
    end
    @unresolvable_addresses = @recipients_by_address.select{ |addr, rcpt| rcpt.nil? }.map(&:first)
    @recipient_addresses = @recipients_by_address.reject{ |attr, rcpt| rcpt.nil? }.map(&:first)
  end

  def restrict_recipients
    # Sometimes the user will try to email members that don't represent them,
    # This filter pares down the @recipient_addresses list, storing the
    # rejected addresses in @rejected_addresses. Those email addresses can be
    # used in the templates for confirmation emails.
    #
    # This leaves the controller method to deal with the error condition since
    # the appropriate action will differ by method.
    if @sender_user
      restrictions = EmailCongress.restrict_recipients(@sender_user, @recipient_addresses)
      @rejected_addresses = restrictions[:rejected]
      @recipient_addresses = restrictions[:allowed]
    end
  end

  def find_by_confirmation_code
    @seed = EmailCongressLetterSeed.find_by_confirmation_code(params[:confirmation_code])
    return render_404 if @seed.nil?
    @email = Postmark::Mitt.new(@seed.raw_source)
    @email_obj = JSON.load(@seed.raw_source)
  end

  def only_resolved
    return render_404 if !@seed.resolved
  end

  def only_unresolved
    return render_404 if @seed.resolved
  end

  def logout_current_user_and_return
    redirect_to({
      :controller => :account,
      :action => :logout,
      :next => url_for(:controller => :email_congress,
                       :action => :confirm,
                       :only_path => true,
                       :confirmation_code => params[:confirmation_code])
    })
  end
end
