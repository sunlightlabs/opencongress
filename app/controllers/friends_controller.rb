class FriendsController < ApplicationController
  #require 'contacts'
  layout 'application'

  before_filter :get_user
  before_filter :login_required, :only => [:invite_form, :import_contacts,:invite_contacts,:new,:add,:create,:destroy,:update,:edit,:confirm]
  before_filter :must_be_owner, :only => [:invite_form, :import_contacts,:invite_contacts,:new,:add,:create,:destroy,:update,:edit,:confirm]
  before_filter :find_bill_by_ident, :only => [:supporting_bill, :opposing_bill]
  before_filter :find_person_by_govtrack_id, :only => [:supporting_person, :opposing_person]

  # GET /friends
  # GET /friends.xml
  def index
    @friends = @user.friends.all
    @fans = @user.fans
    @total_recent_friends_activity = Friend.recent_activity(@friends)
    @recent_friends_activity = @total_recent_friends_activity.first(12) || []
    @more_recent_friends_activity = @total_recent_friends_activity[12..23] || []
    #@page_title = "#{@user.login.possessive} Friends"
    @page_title = "#{@user.login.possessive} Profile"
    @profile_nav = @user
    @title_class = "tab-nav"

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @friends.to_xml }
    end
  end

  # GET /friends/1
  # GET /friends/1.xml
  def show
    @friend = @user.friends.find(params[:id])

    respond_to do |format|
      format.html # show.rhtml
      format.xml  { render :xml => @friend.to_xml }
    end
  end

  # GET /friends/new
  def new
    @friend = @user.friends.new
    @page_title = "#{@user.login.possessive} Profile"
    @title_class = "tab-nav"
    @profile_nav = @user
  end

  # GET /friends/1;edit
  def edit
    @page_title = "Edit a Friend"
    @friend = @user.friends.find(params[:id])
  end

  # POST /friends
  # POST /friends.xml
  def create
    @friend = @user.friends.new(params[:friend])
    @friend.user_id = current_user.id
    respond_to do |format|
      if @friend.save
        flash[:notice] = 'Friend was successfully created.'
        format.html { redirect_to friend_url(@user.login,@friend) }
        format.xml  { head :created, :location => friend_url(@user.login,@friend) }
      else
        format.html { render :action => 'new' }
        format.xml  { render :xml => @friend.errors.to_xml }
      end
    end
  end

  # PUT /friends/1
  # PUT /friends/1.xml
  def update
    @friend = Friend.find(params[:id])

    respond_to do |format|
      if @friend.update_attributes(params[:friend])
        flash[:notice] = 'Friend was successfully updated.'
        format.html { redirect_to friend_url(@user.login,@friend) }
        format.xml  { head :ok }
      else
        format.html { render :action => 'edit' }
        format.xml  { render :xml => @friend.errors.to_xml }
      end
    end
  end

  # DELETE /friends/1
  # DELETE /friends/1.xml
  def destroy
    @friend = Friend.find(params[:id])
    @friend.destroy

    respond_to do |format|
      format.html { redirect_to friends_url(@user.login) }
      format.xml  { head :ok }
    end
  end

  def search
    @results = []
    if params[:email]
      @results = User.find(:all, :conditions => ["LOWER(email) = ?", params[:email].downcase])
    elsif params[:name]
      @results = User.find(:all, :conditions => ["CONCAT(first_name, ' ', last_name) = ?", params[:name].downcase])
    elsif params[:login]
      @results = User.find(:all, :conditions => ["LOWER(login) = ?", params[:login].downcase])
    end
    render :action => 'search', :layout => false
  end

  def invite_form
    render :layout => false
  end

  def filter_by_locality
    if params[:state]
      @state_abbrev = params[:state]
      if @state_name = State.for_abbrev(@state_abbrev)
        @in_my_state = @users.for_state(@state_abbrev)
      end
    elsif logged_in? && !current_user.zipcode.blank?
      @state_abbrev = current_user.state
      @state_name = State.for_abbrev(@state_abbrev)
      @in_my_state = @users.for_state(@state_abbrev)
      @in_my_district = @users.for_district(@state_abbrev, current_user.district)
    end
  end

  def tracking_bill
    bill_type, number, session = Bill.ident params[:id]
    @object = @bill = Bill.find_by_session_and_bill_type_and_number session, bill_type, number
    @users = VisibleByPrivacyOptionQuery.new(
        User.tracking_bill(@bill),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Tracking #{@bill.typenumber}"
    filter_by_locality
  end

  def tracking_person
    @object = @person = Person.find(params[:id])
    @users = VisibleByPrivacyOptionQuery.new(
        User.tracking_person(@person),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Tracking #{@person.short_name}"
    filter_by_locality
  end

  def tracking_issue
    @object = @issue = Subject.find(params[:id])
    @users = VisibleByPrivacyOptionQuery.new(
        User.tracking_issue(@issue),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Tracking #{@issue.term}"
    filter_by_locality
  end

  def tracking_committee
    @object = @committee = Committee.find(params[:id])
    @users = VisibleByPrivacyOptionQuery.new(
        User.tracking_committee(@committee),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Tracking the #{@committee.name} Committee"
    filter_by_locality
  end

  def find_person_by_govtrack_id
    render_404 and return if params[:id].nil?
    @object = @person = Person.find_by_govtrack_id(params[:id])
    render_404 and return if @person.nil?
  end

  def supporting_person
    @users = VisibleByPrivacyOptionQuery.new(
        User.supporting_person(@person),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Supporting #{@person.short_name}"
    filter_by_locality
  end

  def opposing_person
    @users = VisibleByPrivacyOptionQuery.new(
        User.opposing_person(@person),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Opposing #{@person.short_name}"
    filter_by_locality
  end

  def find_bill_by_ident
    render_404 and return if params[:id].nil?
    @object = @bill = Bill.find_by_ident(params[:id])
    render_404 and return if @bill.nil?
  end

  def supporting_bill
    @users = VisibleByPrivacyOptionQuery.new(
        User.supporting_bill(@bill),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Supporting #{@bill.typenumber}"
    filter_by_locality
  end

  def opposing_bill
    @users = VisibleByPrivacyOptionQuery.new(
        User.opposing_bill(@bill),
        :observer => current_user,
        :property => :bookmarks,
        :excludes => @user).all
    @page_title = "Users Opposing #{@bill.typenumber}"
    filter_by_locality
  end

  def near_me
    @title_class = "tab-nav"
    @profile_nav = @user
    @in_state = VisibleByPrivacyOptionQuery.new(
        User.for_state(@user.state),
        :observer => current_user,
        :property => :location,
        :excludes => @user).all
    @in_district = VisibleByPrivacyOptionQuery.new(
        User.for_district(@user.state, @user.district),
        :observer => current_user,
        :property => :location,
        :excludes => @user).all
  end

  def import_contacts
    @page_title = "#{@user.login.possessive} Profile"
    @title_class = "tab-nav"

    if request.post? && params[:from]
      @results = []
      @already = []
      begin

        case params[:from]
        when "google"
          @results = Contacts::Gmail.new(params[:glogin], params[:gpasswd]).contacts
          @already = User.find(:all, :conditions => ["LOWER(email) in (?)", @results.collect{|p| p[1]}.compact])
        when "yahoo"
          @results = Contacts::Yahoo.new(params[:glogin], params[:gpasswd]).contacts
          @already = User.find(:all, :conditions => ["LOWER(email) in (?)", @results.collect{|p| p[1]}.compact])
        when "hotmail"
          @results = Contacts::Hotmail.new(params[:glogin], params[:gpasswd]).contacts
          @already = User.find(:all, :conditions => ["LOWER(email) in (?)", @results.collect{|p| p[1]}.compact])
        end
      rescue
        @login_failed = params[:from]
      end
    end
  end

  def invite_contacts
    if !simple_captcha_valid?
      flash[:notice] = "SPAM Check Failed"
      redirect_to :action => 'import_contacts'
      return
    end

    if request.post? && params[:addfriend]
      message = <<-EOM.strip_heredoc
        (this message was sent by #{current_user.email})

        Hi, I wanted to encourage you to join OpenCongress so that we can share information about bills and issues in Congress.

        Personal Note: #{CGI.escapeHTML(params[:message])}"
      EOM
      @results = []
      params[:addfriend].each_key do |k|
        key = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
        FriendInvite.find_or_create_by_inviter_id_and_invitee_email_and_invite_key(current_user.id, k, key)

        Emailer::invite(k, current_user.full_name.blank? ? current_user.login : current_user.full_name,
                        "#{Settings.base_url}account/invited/#{key}", message).deliver
        @results << k
      end
    end
  end

  def like_voters
    @like_voters = @user.votes_like_me
  end

  def show_recent_comments
    @coms = @user.friends.find_by_id(params[:id]).friend.comments.find(:all, :order => "created_at DESC", :limit => 5)
    render :action => 'show_recent_comments', :layout => false
  end

  def show_recent_votes
    @votes = @user.friends.find_by_id(params[:id]).friend.bill_votes.find(:all, :order => "created_at DESC", :limit => 5)
    render :action => 'show_recent_votes', :layout => false
  end

  def add
   if request.post?
      friend_to_be = User.find_by_id(params[:id])
      if current_user.friends.find_by_id(params[:id])
        render :text => "Already your friend!" and return
      end
      current_user.friends.create({:friend_id => friend_to_be.id, :confirmed => false, :user_id => current_user.id})
      render :text => "Added. #{friend_to_be.login} must confirm, however"
   end
  end

  def confirm
    friending = Friend.find_by_friend_id_and_user_id(current_user.id, params[:id])
    if friending
      friending.confirm
      flash[:notice] = "Friend Added"
      redirect_to friends_path(current_user.login)
    else
      redirect_to friends_path(current_user.login)
    end
  end

  def deny
    friending = Friend.find_by_friend_id_and_user_id(current_user.id, params[:id])
    friending.destroy
    flash[:notice] = "Friending Denied"
    redirect_to friends_path(current_user.login)
  end

  def invite
    if params[:email].blank?
      @message = "You didn't enter an email address!"
    end
    emails = params[:email].split(/,/)
    emails.each do |email|
      email.strip!
      # first check to see if this person is already is a user
      invited_user = User.find_by_email(email)
      if invited_user
        if (invited_user != current_user) and (current_user.friends.find_by_id(invited_user.id).nil?)
          fr = current_user.friends.find_or_initialize_by_friend_id_and_user_id(invited_user.id, current_user.id)
          fr.confirmed = false
          fr.save
        end
      else
        # create the invite record
        key = Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by {rand}.join)
        FriendInvite.find_or_create_by_inviter_id_and_invitee_email_and_invite_key(current_user.id, email, key)

        Emailer::invite(email, current_user.full_name.blank? ? current_user.login : current_user.full_name,
                        "#{Settings.base_url}account/invited/#{key}", params[:message]).deliver
      end
    end

    @message = "Your invitations have been sent!"

    render :layout => false
  end

  private

  def get_user
    if params[:login]
      @user = User.find_by_login(params[:login])
    end
    if @user.nil?
      @user = current_user
    end
  end

  def must_be_owner
    if current_user == @user
      return true
    else
      flash[:error] = "You are not allowed to access that page."
      redirect_to :controller => 'index'
      return false
    end
  end
end
