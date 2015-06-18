require 'o_c_logger'
require_dependency 'email_congress'
class EmailCongressController < ApplicationController
  skip_before_filter :protect_from_forgery, :only => [:complete_profile]
  skip_before_filter :pending_email_seed_prompt
  skip_before_filter :has_district?, :only => [:complete_profile, :confirm, :recipients_for_profile]
  skip_before_filter :must_reaccept_tos?, :only => [:complete_profile, :confirm, :recipients_for_profile]

  # User gets confirmation link or form requesting sender details.

  # Confirmation of email is done via nonce.

  # Users are only able to email their own representatives.

  # All details for a message are stored on an EmailCongressLetterSeed model
  # until it is converted to a FormageddonThread and then disposed of.

  before_filter :login_required, :only => [:discard]
  before_filter :decode_email, :only => [:message_to_members]
  before_filter :find_by_confirmation_code, :only => [:confirm, :complete_profile, :recipients_for_profile, :confirmed, :discard]
  before_filter :only_resolved, :only => [:confirmed]
  before_filter :only_unresolved, :only => [:confirm, :complete_profile, :recipients_for_profile, :discard]
  before_filter :find_user, :only => [:message_to_members, :confirm, :complete_profile, :recipients_for_profile, :discard]
  before_filter :logout_if_necessary, :only => [:confirm, :complete_profile]
  before_filter :lookup_recipients, :only => [:message_to_members, :confirm, :complete_profile, :recipients_for_profile, :confirmed]
  before_filter :override_recipients, :only => [:complete_profile]

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
    # Potential error conditions:
    #   New user
    #   User is not activated
    #   User is trying to email a nonexistent address
    #   User is trying to email someone they are not allowed to email
    #   User is trying to email someone that's been marked as uncontactable

    if @sender_user && @sender_user.is_banned?
      OCLogger.log "Sending incoming email (#{@email.message_id}; #{@email.subject}) to a black hole because it was sent from a banned user (#{@sender_user.id}, #{@sender_user.login})."
      return head :ok
    end

    unless @email_authenticated
      OCLogger.log "Sending incoming email (#{@email.message_id}; #{@email.subject}) to a black hole because it lacks an authenticating BCC header."
      return head :ok
    end

    if @recipient_addresses.empty? && @sender_user
      EmailCongressMailer.no_recipient_bounce(@email).deliver
      return head :ok
    end

    if @email.text_body.blank? && !@email.html_body.blank?
      EmailCongressMailer.must_send_text_version(@email).deliver
      Raven.capture_message "#{@email.from} tried to send an HTML only email"
      return head :ok
    end

    if @uncontactable_recipients.any?
      send_warning_emails({
        uncontactable_officials: @uncontactable_recipients,
        contactable_officials: @recipients,
        incoming_email: @email
      })
      return head :ok unless @recipients.any?
    end

    seed = EmailCongress.seed_for_postmark_object(@email)

    @profile = EmailCongress::ProfileProxy.new(seed)
    if @sender_user
      @profile = @profile.merge(EmailCongress::ProfileProxy.new(@sender_user))
    end

    if @sender_user && @profile.valid? && !@sender_user.district_needs_update?
      EmailCongressMailer.confirmation(seed, @sender_user).deliver
    else
      EmailCongressMailer.complete_profile(seed, @profile).deliver
    end
    head :ok
  end

  def confirm
    # Completes the seed -> letter conversion.

    @page_title = 'Confirm Your Email'
    @profile = EmailCongress::ProfileProxy.new(@seed)
    if @sender_user
      user_profile = EmailCongress::ProfileProxy.build(@sender_user.user_profile, @sender_user)
      @profile = @profile.merge(user_profile)
    end

    if !@profile.valid? || !@sender_user || @recipients.empty?
      # Users who send a message from an unknown address will be directed to
      # :complete_profile in response to their initial email. If they change
      # their email address between the time of the initial email and when they
      # clicked the confirmation link, they would end up here due to the
      # !@sender_user condition.
      flash[:error] = 'To send your message we need to collect the information below.'
      return redirect_to(:action => :complete_profile, :confirmation_code => @seed.confirmation_code)
    end

    # At this point we should have a user and a complete profile.
    begin
      if @sender_user.user_profile.zip_four.blank?
        # Some congress members require the zip_four but we don't include it in the profile form.
        ZipInferrenceService.new(@sender_user.user_profile)
      end
      @profile.copy_to(@seed)
      cc_letter = EmailCongress.reify_for_contact_congress(@sender_user, @seed, @recipients)
      cc_letter.formageddon_threads.each do |thread|
        letter = thread.formageddon_letters.first
        if letter then letter.delay.send_letter() end
      end
      if @uncontactable_recipients.any?
        flash[:notice] = "Unfortunately, we don't yet have working contacts for #{@uncontactable_recipients.map(&:name).to_sentence}, so we cannot send your message to #{@uncontactable_recipients.count} of your recipients."
      end
      @seed.confirm!
      return redirect_to(:action => :confirmed, :confirmation_code => @seed.confirmation_code)
    rescue => e
      raise unless Rails.env.production?
      Raven.capture_exception(e)
      flash[:error] = 'Your letter could not be sent due to technical difficulties. Please try again later.'
      return redirect_to(:action => :complete_profile, :confirmation_code => @seed.confirmation_code)
    end
  end

  def confirmed
    @page_title = "Your Email is Confirmed"
    if logged_in?
      @prompt_for_password = !current_user.password_reset_code.nil?
      @prompt_for_email = current_user.email != @seed.sender_email
    else
      @prompt_for_password = false
      @prompt_for_email = false
    end
  end

  def complete_profile
    @page_title = 'Complete Your Profile and Send Your Email'
    @profile = EmailCongress::ProfileProxy.build(@seed)

    if request.method_symbol == :post
      if params[:profile]
        params[:profile].delete(:email)
        params[:profile][:accept_tos] = (params[:profile][:accept_tos] == '1') || (@sender_user && @sender_user.accepted_tos?)
        @params_profile = EmailCongress::ProfileProxy.new(OpenStruct.new(params[:profile]))
        @profile = @params_profile.merge(@profile) # Values from the form should override existing values
      end

      if @profile.valid?
        if !@sender_user
          @sender_user = User.generate_for_profile(@profile, :suppress_activation_email => true)
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

  def recipients_for_profile
    profile = EmailCongress::ProfileProxy.new(OpenStruct.new(params[:profile]))
    if @sender_user
      profile = profile.merge(@sender_user.user_profile)
    end
    data = {
      :street_address => profile.street_address,
      :city => profile.city,
      :zipcode => profile.zipcode,
      :state => profile.state
    }

    lat, lng = MultiGeocoder.coordinates(data)
    dsts = Congress.districts_locate(lat, lng).results rescue []
    rcpts = dsts.flat_map do |d|
      # district = District.includes(:state).where(:state => { :abbreviation => d[:state] },
      #                                            :district_number => d[:district]).first
      district = District.find_by_district_tag("#{d[:state]}-#{d[:district]}")
      next [district.rep, *district.sens]
    end
    rcpts = Set.new(rcpts.compact).to_a.map do |p|
      phash = p.attributes.slice("govtrack_id", "title", "state", "district")
      phash[:full_name] = p.full_name
      next phash
    end
    render :json => rcpts
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
    return redirect_to(user_actions_path(:login => current_user.login))
  end

  private #############################################################
  def decode_email
    request_body = request.body.read
    @email_obj = JSON.load(request_body)

    inbound_address = Settings.to_hash['email_congress_inbound_address']
    if inbound_address.blank?
      @email_authenticated = true
    else
      bcc = @email_obj["Bcc"]
      # Require that the inbound address is in the Bcc header:
      @email_authenticated = (!bcc.nil? && bcc.downcase.include?(inbound_address.downcase))
      # Strip the inbound address out of the Bcc header. It is a Postmark
      # implementation detail that should be hidden from the rest of the
      # system.
      if !@email_obj["Bcc"].nil?
        @email_obj["Bcc"] = @email_obj["Bcc"].gsub(inbound_address, '')
        @email_obj["BccFull"] = @email_obj["BccFull"].reject{ |pair| pair["Email"].downcase == inbound_address.downcase }
      end
    end

    begin
      @email = Postmark::Mitt.new(JSON.dump(@email_obj))
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
    recipient_addresses = @email_obj.values_at("ToFull", "CcFull", "BccFull").flatten.compact.map{|o| o["Email"]}.uniq
    cleaned = EmailCongress.cleaned_recipient_list(@sender_user, recipient_addresses)
    @recipient_addresses = cleaned.map(&:first)
    @recipients = cleaned.map(&:second)
    @uncontactable_recipients = @recipients.select{|r| r.contactable == false}
    @recipients = @recipients - @uncontactable_recipients
  end

  def override_recipients
    # In the event that someone has sent an email to an official that does not directly represent them and subsequently elects to email all of their representatives, params[:recipient_override]  comes in as true. We make the change to the letter seed's ToFull field.
    if params[:recipient_override] == "true"
      @email_obj["ToFull"] = {"Email" => "myreps@opencongress.org"}
      @email_obj["CcFull"] = []
      @email_obj["BccFull"] = []
      @seed.raw_source = JSON.dump(@email_obj)
      @seed.save!
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

  def send_warning_emails(options={})
    if options[:incoming_email].to.downcase == "myreps@opencongress.org"
      ContactCongressMailer.will_not_send_email_to_all_myreps({
        :uncontactable_officials => options[:uncontactable_officials],
        :contactable_officials => options[:contactable_officials],
        :message_body => @email.text_body,
        :recipient_email => @email.from_email
      }).deliver
      Raven.capture_message "sent #{@email.from_email} a message about uncontactable parts of myreps (#{options[:uncontactable_officials].map(&:name)})"
    else
      options[:uncontactable_officials].each do |r|
        ContactCongressMailer.will_not_send_email({
          :uncontactable_official => r,
          :message_body => @email.text_body,
          :recipient_email => @email.from_email
        }).deliver
        Raven.capture_message "sent #{@email.from_email} a message about uncontactable recipient #{r.name}"
      end
    end
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
