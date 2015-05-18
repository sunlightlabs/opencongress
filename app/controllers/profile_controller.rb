require 'net/http'

class ProfileController < ApplicationController
  include ProfileHelper

  before_filter :can_view_tab, :only => [:actions, :items_tracked, :downloads_index, :bills, :my_votes, :comments, :person, :issues, :watchdog]
  before_filter :login_required, :only => [:edit, :update, :destroy, :upload_pic, :delete_images, :disconnect_facebook_account]
  skip_before_filter :verify_authenticity_token, :only => :edit_profile
  skip_before_filter :must_reaccept_tos?, :only => [:show, :edit, :update, :destroy, :upload_pic, :delete_images]
  skip_before_filter :has_district?, :only => [:edit, :update, :destroy, :upload_pic, :delete_images]
  skip_before_filter :pending_email_seed_prompt, :only => [:actions]

  def show
    @user = User.find_by_login(params[:login], :include => [:bookmarks]) # => [:bill]}])
    return render_404 if @user.nil?
    @page_title = "#{@user.login.possessive} Profile"
    @title_class = "tab-nav"
    @profile_nav = @user
  end

  def edit
    @user = current_user
    redirect_to edit_profile_path(@user.login) unless params[:login] == @user.login
  end

  def update
    @user = current_user
    if params[:user][:password].present? && params[:user][:password_confirmation].present?
      old_pass = params[:user].delete(:current_password)
      new_pass = params[:user].delete(:password)
      if new_pass != params[:user].delete(:password_confirmation)
        flash[:error] = "Passwords do not match, your profile was not updated."
        redirect_to :back and return
      end
      if (params[:user][:password_reset_code].present? && (params[:user][:password_reset_code] == @user.password_reset_code)) || User.authenticate(@user.login, old_pass).is_a?(User)
        @user.reset_password
        @user.password = new_pass
        @user.save
        @user.instance_variable_set(:@reset_password, nil)
        flash[:notice] = "Your new password has been set."
      else
        flash[:error] = "Your old password was incorrect."
        redirect_to :back and return
      end
    end
    if @user.update_attributes(params[:user])
      flash[:notice] = 'Your profile was updated.'
      redirect_to user_profile_path(@user.login)
    else
      flash[:warning] = @user.errors.full_messages.to_sentence
      redirect_to :back
    end
  end

  def destroy
    current_user.deactivate!
    flash[:success] = 'Your profile has been deleted.'
    redirect_to "/"
  end

  def howtouse
    @page_title = "Ways To Use \"My OpenCongress\""
  end

  def user_actions_rss
    @user = User.find_by_login(params[:login])
    @items = @user.recent_actions
    render :action => "new_link.rxml", :layout => false
  end

  def actions
    @user = User.find_by_login(params[:login], :include => [:bookmarks]) # => [:bill, {:person => :roles}]}])
    @page_title = "#{@user.login.possessive} Profile"
    @profile_nav = @user

    @bills_supported = Bill.paginate_by_sql("select bills.* FROM bills
                      INNER JOIN (select bill_votes.support, bill_votes.user_id,
                        bill_votes.created_at, bill_votes.bill_id FROM bill_votes WHERE bill_votes.support = 0
                        AND bill_votes.user_id = #{@user.id}) b ON b.bill_id = bills.id
                      ORDER BY b.created_at", :per_page=>20, :page => params[:s_page])

    @bills_opposed = Bill.paginate_by_sql("select bills.* FROM bills
                      INNER JOIN (select bill_votes.support, bill_votes.user_id,
                        bill_votes.created_at, bill_votes.bill_id FROM bill_votes WHERE bill_votes.support = 1
                        AND bill_votes.user_id = #{@user.id}) b ON b.bill_id = bills.id
                      ORDER BY b.created_at", :per_page=>20, :page => params[:o_page])

    if logged_in?
      @unfinished_emails = EmailCongress.pending_seeds(current_user.email).sort_by(&:created_at).reverse
    end

    @title_class = "tab-nav"
    @atom = {'link' => url_for(:only_path => false, :controller => 'user_feeds', :login => @user.login, :action => 'actions', :key => logged_in? ? current_user.feed_key : nil), 'title' => "#{@user.login.possessive} Actions"}
    @my_comments = Comment.paginate(:conditions => ["user_id = ?", @user.id], :order => "created_at DESC", :page => params[:page])
  end

  def downloads_index
    @page_title = "#{@user.login.possessive} Profile"
    @user = User.find_by_login(params[:login], :include => [:bookmarks]) # => [:bill, {:person => :roles}]}])
    @profile_nav = @user
    @title_class = "tab-nav"

    respond_to do |format|
      format.html
      if params.has_key? 'items_tracked'
        format.csv { render text: to_csv(@user) }
      end
    end

  end

  def items_tracked
    @atom = {'link' => url_for(:controller => 'user_feeds', :login => @user.login, :action => 'tracked_items', :key => logged_in? ? current_user.feed_key : nil)}
    @hide_atom = true
    @user = User.find_by_login(params[:login], :include => [:bookmarks]) # => [:bill, {:person => :roles}]}])
    @page_title = "#{@user.login.possessive} Profile"
    @profile_nav = @user
    @title_class = "tab-nav"

    if logged_in? && current_user.id == @user.id
      mailing_list = UserMailingList.find_or_create_by_user_id(@user.id)
      @show_email_alerts = true
    else
      @show_email_alerts = false
    end
     @bills = @user.bill_bookmarks
     @bill_items_tracked = []
     @bill_items_tracked = Bill.find_changes_since_for_bills_tracked(@user) if @bills.length > 0
     @user.representative_bookmarks.length > 0 ? @rep_items_tracked = Person.find_changes_since_for_representatives_tracked(@user) : @rep_items_tracked = []
     @user.senator_bookmarks.length > 0 ? @sen_items_tracked = Person.find_changes_since_for_senators_tracked(@user) : @sen_items_tracked = []
     respond_to do |format| 
       format.html
       format.csv { render text: to_csv(@user) }
     end
  end

  def tracked_bill_status
    @bill = Bill.find_by_id(params[:id])
    @limit = params[:limit].to_i
    @limit > 5 ? @limit = 5 : @limit = @limit
    render :text => '<h3 class="darkline">Recent Actions</h3>' +
    render_to_string(:partial => 'bill/action_list_recent', :locals => { :actions => @bill.actions.find(:all, :limit => @limit) }, :layout => false )
  end

  def tracked_votes
    @person = Person.find_by_id(params[:id])
    @limit = params[:limit].to_i
    @limit > 30 ? @limit = 30 : @limit = @limit
    render :text => '<h3 class="darkline">Recent Voting History </h3>' +
    render_to_string(:partial => 'people/voting_history', :locals => { :votes => @person.votes(@limit.to_i) }, :layout => false) +
    '<p><a href="/people/voting_history/<%= person.to_param %>"><img src="/images/btn-voting-history.gif" class="noborder"></a></p>'
  end

  def tracked_commentary_news
    @limit = params[:limit].to_i
    @limit > 5 ? @limit = 5 : @limit = @limit
    if params[:object] == "Bill"
      bill = Object.const_get(params[:object]).find_by_id(params[:id])
      render :partial => 'shared/news', :object => bill.news.find(:all, :limit => @limit),
          :locals => { :limit => @limit, :all_size => bill.news_article_count, :default_title => bill.title_common,
                       :more_url => { :controller => 'bill', :action => 'news', :id => bill.ident } }
    elsif params[:object] ==  "Person"
      person = Object.const_get(params[:object]).find_by_id(params[:id])

      render :partial => 'shared/news', :object => person.news.find(:all, :limit => @limit),
        :locals => { :limit => @limit, :all_size => person.news_article_count, :default_title => person.name,
                     :more_url => { :controller => 'people', :action => 'news', :id => person } }
    else
      render :nothing
      return
    end
  end

  def tracked_commentary_blogs
    @limit = params[:limit].to_i
    @limit > 5 ? @limit = 5 : @limit = @limit
    if params[:object] == "Bill"
      bill = Object.const_get(params[:object]).find_by_id(params[:id])
      render :partial => 'shared/blogs', :object => bill.blogs.find(:all, :limit => @limit),
          :locals => { :limit => @limit, :all_size => bill.blog_article_count, :default_title => bill.title_common,
                       :more_url => { :controller => 'bill', :action => 'blogs', :id => bill.ident } }
    elsif params[:object] ==  "Person"
      person = Object.const_get(params[:object]).find_by_id(params[:id])

      render :partial => 'shared/blogs', :object => person.blogs.find(:all, :limit => @limit),
        :locals => { :limit => @limit, :all_size => person.blog_article_count, :default_title => person.name,
                     :more_url => { :controller => 'people', :action => 'blogs', :id => person } }
    else
      render :nothing
      return
    end
  end

  def bills
    @user = User.find_by_login(params[:login])
    @page_title = "Profile of #{@user.login} - Bills Tracked"
    @bookmarks = Bookmark.find_bookmarked_bills_by_user(@user.id)

    if params[:format]

      expires_in 60.minutes, :public => true
      render :action => "new_link.rxml", :layout => false
    else
      render :action => "bills.html.erb"
    end
  end

  def groups
    @page_title = "My Groups"
    @user = User.find_by_login(params[:login])
    @groups = @user.active_groups.paginate(:per_page => 20, :page => params[:page])
  end

  def my_votes
    @user = User.find_by_login(params[:login])
    @page_title = "Profile of #{@user.login} - Bills Voted On"
    @bills_supported = @user.bill_votes.find_all_by_support(0)
    @bills_opposed = @user.bill_votes.find_all_by_support(1)
    @bill_votes = @bills_supported.concat(@bills_opposed)


    if params[:format]
      @title = "Bills #{params[:login]} supports & opposes"
      @items = []
      @bill_votes.each do |b|
        @items << b.bill.actions.to_a
      end
      @items.flatten!
      @items.sort! { |x,y| y.date <=> x.date }
      expires_in 60.minutes, :public => true

      render :action => "new_link.rxml", :layout => false
    else
      render :action => 'my_votes'
    end
  end

  def remove_vote
    bill_vote = current_user.bill_votes.find_by_bill_id(params[:id])
    bill_vote.destroy
    flash[:notice] = "Vote removed."
    redirect_back_or_default(:action => 'index', :login => current_user.login)
  end

  def remove_bill_bookmark
    bookmark = current_user.bookmarks.find_by_bookmarkable_type_and_bookmarkable_id("Bill", params[:id])
    remove_bookmark(bookmark, (bookmark.bill.typenumber rescue nil))
  end

  def remove_person_bookmark
    bookmark = current_user.bookmarks.find_by_bookmarkable_type_and_bookmarkable_id("Person", params[:id])
    remove_bookmark(bookmark, "#{bookmark.person.title rescue nil} #{bookmark.person.full_name rescue nil}")
  end

  def remove_committee_bookmark
    bookmark = current_user.bookmarks.find_by_bookmarkable_type_and_bookmarkable_id("Committee", params[:id])
    remove_bookmark(bookmark, (bookmark.commitee.name rescue 'Committee'))
  end

  def remove_subject_bookmark
    bookmark = current_user.bookmarks.find_by_bookmarkable_type_and_bookmarkable_id("Subject", params[:id])
    remove_bookmark(bookmark, "Issue '#{bookmark.subject.term rescue nil}'")
  end

  # Takes bookmark, either int id or Bookmark object,
  # confirms it belongs to current_user and deletes it.
  def remove_bookmark(bookmark = nil, name = 'Bookmark')
    bookmark = params[:id].to_i if bookmark.nil?
    if bookmark.is_a? Integer
      bookmark = current_user.bookmarks.find_by_id(bookmark) if bookmark.is_a? Integer
    end
    if bookmark && bookmark.user == current_user
      destroyed = bookmark.destroy rescue false
    end
    flash[:notice] = destroyed ? "#{name} removed from your tracking list." : "There was an error removing #{name}"
    redirect_back_or_default(:action => 'items_tracked', :login => current_user.login)
  end

  def comments
    @user = User.find_by_login(params[:login])
    @page_title = "Profile of #{@user.login} - Comments"
#    @comments = Comment.find(:all, :conditions => ["user_id = ?", @user.id], :order => "created_at DESC", :page => {:size => 10, :current => params[:page]})

    if params[:format]
      @comments = Comment.find(:all, :conditions => ["user_id = ?", @user.id], :order => "created_at DESC", :limit => 20)
      expires_in 60.minutes, :public => true
      render :action => "comments.rxml", :layout => false
    else
      @comments = Comment.find(:all, :conditions => ["user_id = ?", @user.id], :order => "created_at DESC", :page => {:size => 10, :current => params[:page]})
      render :action => "comments.html.erb"
    end
  end

  def person
    role_type = String.new
    case params[:person_type]
      when "senators"
        role_type = "sen"
      when "representatives"
        role_type = "rep"
    end
    @ptype = params[:person_type].capitalize
    @user = User.find_by_login(params[:login])
    @page_title = "Profile of #{@user.login} - #{params[:person_type].capitalize} Tracked"
    @bookmarks = @user.representative_bookmarks if role_type == "rep"
    @bookmarks = @user.senator_bookmarks if role_type == "sen"


    if params[:format]
      expires_in 60.minutes, :public => true

      @items = []
      @bookmarks.each do |b|
        @items << b.person.last_x_bills(10).to_a
#        @items << b.person.bills.to_a
        @items.concat(b.person.votes(10).to_a)
      end
      @items.flatten!
      @items.sort! { |x,y| y.sort_date <=> x.sort_date }

      render :action => "new_link.rxml", :layout => false
    else
      render :action => "person.html.erb"
    end
  end

  def tracked_rss
    @user = User.find_by_login(params[:login])
    @title = "All things I'm Tracking"

    @tracked_issues = @user.issue_bookmarks
    @tracked_bills = Bookmark.find_bookmarked_bills_by_user(@user.id)
    @tracked_people = @user.legislator_bookmarks
    @tracked_committees = @user.committee_bookmarks

    @items = []

    @tracked_issues.each do |i|
      @items.concat(i.subject.latest_major_actions(5))
    end
    @tracked_people.each do |p|
        @items.concat(p.person.bills.to_a)
        @items.concat(p.person.votes(10).to_a)
    end

    @tracked_bills.each do |b|
      @items.concat(b.bill.last_5_actions.to_a)
    end

    @tracked_committees.each do |b|
      @items.concat(b.bookmarkable.latest_reports(5).to_a)
      @items.concat(b.bookmarkable.latest_major_actions(5))
    end

    @items.flatten!
    @items.sort! { |x,y| y.rss_date <=> x.rss_date }
    expires_in 60.minutes, :public => true

    render :action => "new_link.rxml", :layout => false
  end


  def issues
    @user = User.find_by_login(params[:login])
    @page_title = "Profile of #{@user.login} - Issues tracked"
    @bookmarks = Bookmark.find(:all, :conditions => ["bookmarkable_type = ? AND user_id = ?", "Subject", @user.id])

    if params[:format]
      @title = "Issues I'm Tracking"
      @items = []
      @bookmarks.each do |b|
        @items << b.subject.latest_major_actions(5)
      end
      @items.flatten!
      @items.sort! { |x,y| y.date <=> x.date }
      expires_in 60.minutes, :public => true

      render :action => "new_link.rxml", :layout => false
    else
      render :action => 'issues'
    end

  end

  def committees
    @user = User.find_by_login(params[:login])
    @page_title = "Profile of #{@user.login} - Committees tracked"
    @bookmarks = Bookmark.find(:all, :conditions => ["bookmarkable_type = ? AND user_id = ?", "Committee", @user.id])


    if params[:format]
      @title = "Commitees I'm Tracking"
      @items = []
      @bookmarks.each do |b|
        @items << b.committee.latest_major_actions(5)
      end
      @items.flatten!
      @items.sort! { |x,y| y.date <=> x.date }
      expires_in 60.minutes, :public => true

      render :action => "new_link.rxml", :layout => false
    else
      render :action => 'committees'
    end

  end


  def edit_profile
    logger.debug "Current user: #{current_user.inspect}"
    if logged_in?
      @user = current_user
      field = params[:field]
      value = params[:value]

      if value == "[Click to Edit]"
        render :text => "[Click to Edit]"
        return
      end

      case field
      when "user_role", "user_role_id", "login"
        render :text => "Nope"
      else
        logger.debug "Setting '#{field}' to '#{value}'"
        @user[field] = value
        @user[field] = nil if ( field == "zipcode" && value == "" )
        @user[field] = nil if ( field == "zip_four" && value == "" )
        if @user.valid?
          @user.save
          render :action => 'edit_profile', :layout => false
        else
          if field == "zip_four"
            render :text => "Must be a 4 digit zip extension"
          else
            render :text => "Invalid input"
          end
        end
      end
    else
      logger.debug "BBBBBBBBBBBBBBBBBOUNCED"
    end
  end

  def track
    if logged_in?
      object = Object.const_get(params[:type])
      @this_object = object.find_by_id(params[:id])
      if @this_object
        bookmark = Bookmark.new(:user_id => current_user.id)
        @this_object.bookmarks << bookmark
      end
      render :update do |page|
        if params[:multi]
          page.replace_html "trackli#{@this_object.id}", "I'm tracking this " + (object.to_s == "Subject" ? "Issue" : object.to_s)
        else
          page.replace_html "b_myoc_txt", "Tracking Now"
          page['b_myoc'].add_class_name 'tracking'
        end
      end
    else
      render :update do |page|
        page.redirect_to login_url
      end
    end
  end

  def update_privacy
     @user = current_user
     params[:user_privacy_options].delete("user_id")
     @user.user_privacy_options.update_attributes(params[:user_privacy_options])
     flash[:notice] = "Privacy Setting Updated"
     redirect_back_by_referer_or_default(user_profile_path(@user.login))
  end

  def upload_pic
    begin
      tmp_file = params[:picture]['tmp_file']
      avatar = Avatar.new(tmp_file.read, :name => current_user.login)
      current_user.user_profile.main_picture, current_user.user_profile.small_picture = avatar.create_sizes!
      current_user.save(:validate => false)
    rescue
      flash.now[:warning] = 'Failed to upload your picture'
    end
    if request.xhr?
      profile_image_for(current_user)
    else
      # redirect_back_or_default(user_profile_path(current_user.login))
      redirect_to :back
    end
  end

  def disconnect_facebook_account
    if current_user.facebook_uid
      current_user.facebook_uid = nil
      if current_user.save() and current_user.reload()
        @facebook_user = nil
        force_fb_cookie_delete
        session.delete(:facebook_user)
        return request.xhr? ? profile_facebook_for(current_user) : (redirect_to :back)
      end

      # TODO handle response in case of no javascript
      # url = "https://graph.facebook.com/#{current_user.facebook_uid}/permissions/?access_token=" + params[:access_token]
      # result = Net::HTTP::Delete(URI.parse(url))
      # if result.code == '200'
      # end
    end

    return request.xhr? ? 'false' : (redirect_to :back)
  end

  def delete_images
    File.delete("#{Avatar::DEFAULT_UPLOAD_PATH}#{current_user.user_profile.main_picture}") if current_user.main_picture.present? rescue nil
    File.delete("#{Avatar::DEFAULT_UPLOAD_PATH}#{current_user.user_profile.small_picture}") if current_user.small_picture.present? rescue nil
    current_user.user_profile.main_picture = current_user.user_profile.small_picture = nil
    current_user.save(:validate => false)
    if request.xhr?
      flash.now[:notice] = "Profile picture deleted"
      profile_image_for(current_user)
    else
      flash[:notice] = "Profile picture deleted"
      # redirect_back_or_default(user_profile_path(current_user.login))
      redirect_to :back
    end
  end

  def hide_field
    @user = current_user
    @user.toggle!(params[:type])
    redirect_to user_profile_url(current_user.login)
  end

  def ratings
    this_rating = params[:user][:user_options_attributes][:comment_threshold].to_i
    logger.info(this_rating.to_s + " DEFAU")
    if this_rating > -1 && this_rating < 11
      user = current_user
      user.update_attribute(:comment_threshold, this_rating)
    end
    redirect_to :controller => 'profile', :action => 'show', :login => current_user.login, :anchor => "comm_fil"
  end

  def watchdog
    @page_title = "WatchDog"
    @title_class = "tab-nav"
    @profile_nav = @user
    @my_state = State.find_by_abbreviation(@user.state)
    @my_district = @user.district
    if @user.definitive_district
      @my_district = District.find_by_district_number_and_state_id(@my_district, @my_state.id)
#      @watchdog = @user.definitive_district_object.current_watch_dog.user if @user.definitive_district_object.current_watch_dog
    end
    @bookmarked_bills = @user.bookmarked_bills
    logger.info @bookmarked_bills.length

  end

  def pn_ajax
    @commentary = Commentary.find_by_id(params[:id])
    if ["Person", "Bill", "Commentary"].include?(params[:object_type])
      @object = Object.const_get(params[:object_type]).find_by_id(params[:object_id])
    end

    render :layout => false

  end

  private

  def to_csv(user)
    session[:track_item_banner] = true
    CSV.generate(headers: true) do |csv|
      csv << ['Type', 'Name', 'Bioguide_id', 'Type Number', 'Chamber']
      user.tracked_items_export.each { |i| csv << i } 
    end
  end

  def can_view_tab
    @user = User.find_by_login(params[:login])
    if params[:action] == "actions" && @user.can_view(:actions, current_user)
      return true
    elsif params[:action] == "watchdog" && @user.can_view(:watchdog, current_user)
      return true
    elsif @user.can_view(:bookmarks, current_user)
      return true
    else
      flash[:warning] = "That page isn't publicly viewable."
      redirect_to :back and return
    end
  rescue
      redirect_to "/" and return
  end
end

