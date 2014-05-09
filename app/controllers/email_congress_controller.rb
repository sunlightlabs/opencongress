require_dependency 'email_congress'
class EmailCongressController < ApplicationController


  # User gets confirmation link or form requesting sender details.

  # Confirmation of email is done via nonce.

  # Users are only able to email their own representatives.

  # All details for a message are stored on an EmailCongressLetterSeed model
  # until it is converted to a FormageddonThread and then disposed of.

  before_filter :decode_email, :only => [:message_to_members]
  before_filter :find_by_confirmation_code, :only => [:confirm, :complete_profile, :confirmed]
  before_filter :only_resolved, :only => [:confirmed]
  before_filter :only_unresolved, :only => [:confirm, :complete_profile]
  before_filter :find_user, :only => [:message_to_members, :confirm, :complete_profile]
  before_filter :logout_if_necessary, :only => [:confirm, :complete_profile]
  before_filter :lookup_recipients, :only => [:message_to_members]
  before_filter :restrict_recipients, :only => [:message_to_members]

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

    seed = EmailCongressLetterSeed.new
    seed.raw_source = JSON.dump(@email_obj)
    seed.sender_email = @email.from_email
    seed.email_subject = @email.subject
    seed.email_body = @email.text_body
    seed.save!

    if @email.text_body.blank? && !@email.html_body.blank?
      EmailCongressMailer.html_body_alert(seed).deliver
      return head :ok
    end

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
      user_profile = EmailCongress::ProfileProxy.new(@sender_user)
      @profile = @profile.merge(user_profile)
    end

    if !@sender_user || !@profile.valid?
      # Users who send a message from an unknown address will be directed to
      # :complete_profile in response to their initial email. If they change
      # their email address between the time of the initial email and when they
      # clicked the confirmation link, they would end up here due to the
      # !@sender_user condition.
      flash[:error] = @profile.errors.full_messages.to_sentence
      return redirect_to(:action => :complete_profile,
                         :confirmation_code => @seed.confirmation_code)
    end

    # We have a user and a complete profile.
    @profile.copy_to(@seed)
    @seed.confirm!
    # TODO: Actually convert to thread
    puts "CONFIRMED SEED #{@seed.id}: #{@seed.email_subject}"
    return redirect_to(:action => :confirmed, :confirmation_code => @seed.confirmation_code)
  end

  def confirmed
    # TODO: Probably don't want to use application layout
  end

  def complete_profile
    @seed_profile = EmailCongress::ProfileProxy.new(@seed)
    @user_profile = EmailCongress::ProfileProxy.new(@sender_user || OpenStruct.new)
    @profile = @seed_profile.merge(@user_profile)
    if params[:profile]
      params[:profile][:accept_tos] = (params[:profile][:accept_tos] == 'true')
      @params_profile = EmailCongress::ProfileProxy.new(OpenStruct.new(params[:profile]))
      @profile = @params_profile.merge(@profile) # Values from the form should override existing values
    end

    if request.method_symbol == :post
      if @profile.valid?
        if !@sender_user
          @sender_user = User.generate_for_profile(@profile)
        else
          # TODO: Copy ProfileProxy to UserProfile instead of User
          @profile.copy_to(@sender_user)
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
    end
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

  def reload_email
    @email = Postmark::Mitt.new(@seed.raw_source)
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
    @recipient_addresses = EmailCongress.expand_special_addresses(@recipient_addresses)
    @recipients_by_address = Hash.new
    @recipient_addresses.each do |addr|
      begin
        @recipients_by_address[addr] = EmailCongress.congressmember_for_address(addr)
      rescue
        @recipients_by_address[addr] = nil
      end
    end
    @nonexistent_addresses = @recipients_by_address.select{ |_, rcpt| rcpt.nil? }.map(&:first)
  end

  def restrict_recipients
    # Sometimes the user will try to email members that don't represent them,
    # This filter pares down the @recipient_addresses list, storing the
    # rejected addresses in @rejected_addresses. Those email addresses can be
    # used in the templates for confirmation emails.
    if @sender_user
      req_set = Set.new(@recipient_addresses)
      legit_set = Set.new(@sender_user.my_congress_members)
      @rejected_addresses = (req_set - legit_set).to_a
      @recipient_addresses = (req_set & legit_set).to_a
    end
  end

  def find_by_confirmation_code
    @seed = EmailCongressLetterSeed.find_by_confirmation_code(params[:confirmation_code])
    return render_404 if @seed.nil?
    @email = Postmark::Mitt.new(@seed.raw_source)
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
