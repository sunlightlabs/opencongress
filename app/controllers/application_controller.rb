require 'authenticated_system'
require_dependency 'email_congress'

class ApplicationController < ActionController::Base

  protect_from_forgery :if => :logged_in?

  include AuthenticatedSystem
  include SimpleCaptcha::ControllerHelpers
  include Facebooker2::Rails::Controller
  include UrlHelper

  helper_method :current_congress
  
  # around_filter :maintenance

  before_filter :require_utf8_params
  before_filter :facebook_check
  before_filter :clear_return_to
  before_filter :current_tab
  before_filter :has_accepted_tos?
  before_filter :must_reaccept_tos?
  before_filter :warn_reaccept_tos?
  before_filter :has_district?
  before_filter :pending_email_seed_prompt
  before_filter :get_site_text_page
  before_filter :is_authorized?
  before_filter :set_simple_comments
  before_filter :last_updated
  after_filter :cache_control
  after_filter :capture_cta

  class InvalidByteSequenceErrorFromParams < Encoding::InvalidByteSequenceError
    # Empty
  end

  def force_utf8_params
    traverse = lambda do |object, block|
      if object.kind_of?(Hash)
        object.each_value { |o| traverse.call(o, block) }
      elsif object.kind_of?(Array)
        object.each { |o| traverse.call(o, block) }
      else
        block.call(object)
      end
      object
    end
    force_encoding = lambda do |o|
      if o.respond_to?(:force_encoding)
        o.force_encoding(Encoding::UTF_8)
        raise InvalidByteSequenceErrorFromParams unless o.valid_encoding?
      end
      if o.respond_to?(:original_filename)
        o.original_filename.force_encoding(Encoding::UTF_8)
        raise InvalidByteSequenceErrorFromParams unless o.original_filename.valid_encoding?
      end
    end
    traverse.call(params, force_encoding)
    path_str = request.path.to_s
    if path_str.respond_to?(:force_encoding)
      path_str.force_encoding(Encoding::UTF_8)
      raise InvalidByteSequenceErrorFromParams unless path_str.valid_encoding?
    end
  end

  def require_utf8_params
    begin
      force_utf8_params
    rescue InvalidByteSequenceErrorFromParams
      return render_404
    end
  end

  ##
  # This method allows a user to login through facebook and persist their
  # account throughout use of OpenCongress.
  #
  def facebook_check

    # This is ninjutsu logic to allow a user to logout of OpenCongress without logging out
    # of facebook too. The parameter "fblogin" is passed on first login through facebook
    # which allows this method to give a "session_cookie" to the user.
    return if (session[:nofacebook] || (session[:session_cookie].nil? && !params[:fblogin]))

    unless params[:fbcancel].nil?
      force_fb_cookie_delete
      @facebook_user = nil
      session[:facebook_user] = nil
      session[:nofacebook] = true

      flash.now[:notice] = 'Facebook Connect has been cancelled.'
      return
    end

    # check to see if the user is logged into and has connected to OC
    begin
      if current_facebook_user && current_facebook_client
        begin
          @facebook_user = Mogli::User.find(current_facebook_user.id, current_facebook_client, :email, :name, :first_name, :last_name)
        rescue Mogli::Client::HTTPException
          force_fb_cookie_delete
          @facebook_user = nil
        end
      else
        @facebook_user = nil
        force_fb_cookie_delete
      end
    rescue Mogli::Client::OAuthException
      force_fb_cookie_delete
      @facebook_user = nil
    end

    # TODO: Use omniauth or other, this is terrible.
    @facebook_user = session[:facebook_user] if @facebook_user.nil? && session[:facebook_user].present?

    if @facebook_user
      session[:facebook_user] = @facebook_user
      # the user isn't logged in, try to find the account based on email
      if current_user == :false
        oc_user = User.where(["email=?", @facebook_user.email]).first
      else
        # if the logged-in user's email matches the one from facebook, use that user
        # otherwise, cancel the facebook connect attempt
        if current_user.email == @facebook_user.email
          return unless current_user.facebook_uid.blank?
          oc_user = current_user
        else
          flash[:error] = 'The email addresses in your Facebook and OpenCongress accounts do not match.  Could not connect.'
          force_fb_cookie_delete
          @facebook_user = nil
          return
        end
      end

      if oc_user
        # if, for some reason, we don't have these fields, require them
        if oc_user.login.blank? or oc_user.zipcode.blank? or !oc_user.accepted_tos?
          redirect_to :controller => 'account', :action => 'facebook_complete' and return unless params[:action] == 'facebook_complete'
        end

        # make sure we have facebook uid
        if oc_user.facebook_uid.blank?
          oc_user.facebook_uid = @facebook_user.id
          oc_user.save

          flash.now[:notice] = 'Your Facebook account has now been linked to this OpenCongress account!'
        else
          flash.now[:notice] = "Welcome, #{oc_user.login}."
        end

        # log the user in
        self.current_user = oc_user
      else
        # new user.  redirect to get essential info
        redirect_to :controller => 'account', :action => 'facebook_complete' and return unless params[:action] == 'facebook_complete'
      end
    end
  end

  def is_valid_email?(e, with_headers = false)
    if with_headers == false
      email_check = Regexp.new('^[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$')
    else
      email_check = Regexp.new('[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]')
    end

    if (e =~ email_check) == nil
      false
    else
      true
    end
  end

  def days_from_params(days)
    days = days.to_i if (days && !days.kind_of?(Integer))
    return (days && ((days == 7) || (days == 14) || (days == 30) || (days == 365))) ? days.days : Settings.default_count_time
  end

  def comment_redirect(comment_id)
    comment = Comment.find_by_id(comment_id)
    render_404 and return unless comment.present?
    if comment.commentable_type == "Article"
      redirect_to comment.commentable_link.merge(:action => 'view', :comment_page => comment.page, :comment_id => comment_id)
    else
      redirect_to comment.commentable_link.merge(:action => 'comments', :comment_page => comment.page, :comment_id => comment_id)
    end
    @goto_comment = comment
  end

#  def render(opts)
#    ap(__callee__)
#    calling_controller = parse_caller(caller[0])[0].split('/')[-1].gsub('_controller.rb','')
#    ap(calling_controller)
#    hash = opts.is_a?(::Hash) ? opts : {}
#    hash['stream'] = true
#    if opts.is_a?(::String) then hash['template'] = opts end
#    super(hash) rescue super(opts)
#  end
  
  def current_congress
    params[:congress] ? params[:congress].to_i : Settings.default_congress
  end

  def congress_in_session
    CongressSession.
  end

  private

  ##
  # Sets the @user instance variable to login argument. Defaults to the :login parameter. This method
  # can be used in conjunction with must_be_owner and filters to tailor views for the current_user
  #
  # @param  login   set the @user instance variable to the provided login (if the user exists)
  #
  def set_user_by_login!(login=params[:login])
    if login
      @user ||= User.find_by_login(login) and return
    end
    if @user.nil? && logged_in? && login.blank?
      redirect_to url_for(:controller => params[:controller], :action => login, :login => current_user.login)
    else
      render_404
    end
  end

  def must_be_owner
    if current_user == @user
      return true
    else
      flash[:error] = 'You are not allowed to access that page.'
      redirect_to :controller => 'index'
      return false
    end
  end

  def has_accepted_tos?
    if logged_in?
      unless current_user.accepted_tos?
        redirect_to :controller => 'account', :action => 'accept_tos' and return
      end
    end
  end

  def must_reaccept_tos?
    if logged_in?
      if current_user.status == User::STATUSES[:reaccept_tos]
        redirect_to :controller => 'account', :action => 'reaccept_tos' and return
      end
    end
  end

  def warn_reaccept_tos?
    if logged_in?
      if current_user.status == User::STATUSES[:reaccept_tos]
        flash.now[:info] = %Q[Our Default privacy settings have changed. <a href="/account/reaccept_tos">Click here to review and accept the changes</a>.].html_safe
      end
    end
  end

  def pending_email_seed_prompt
    if logged_in?
      seeds = EmailCongress.pending_seeds(current_user.email)
      if seeds.count == 1
        flash.now[:info] = %Q[You have an unfinished email re: <a href="#{url_for(:controller => :email_congress, :action => :complete_profile, :confirmation_code => seeds.first.confirmation_code)}">#{seeds.first.email_subject}</a>].html_safe
      elsif seeds.count > 1
        flash.now[:info] = %Q[You have #{seeds.count} <a href="#{user_actions_path(:login => current_user.login)}">unfinished emails</a>].html_safe
      end
    end
  end

  def has_district?
    if logged_in?
      if current_user.state.nil? or current_user.my_district.size != 1
        redirect_to(url_for(:controller => 'account', :action => 'determine_district')) unless (
          params[:action] == 'determine_district' or
          params[:action] == 'accept_tos' or
          params[:action] == 'logout'
        )
      end
    end
  end

  def capture_cta

    if not logged_in? and not cookies.has_key?(:cta_session)
      cookies[:cta_session] = session[:session_id]
      session[:cta_session] = session[:session_id]
    end

    user_id = logged_in? ? current_user.id : nil
    last_cta = user_id.present? ? UserCtaTracker.where(user_id:user_id).last :
                                  UserCtaTracker.where(session_id:cookies[:cta_session]).last

    if last_cta.nil? or (Time.now - last_cta.created_at) > UserCtaTracker::LAST_ACTION_THRESHOLD
      pa_id = nil
    else
      pa_id = last_cta.id
    end

    UserCtaTracker.create(user_id: user_id,
                          session_id: cookies[:cta_session],
                          previous_action_id: pa_id,
                          url_path: request.fullpath,
                          controller: params[:controller],
                          method: params[:action],
                          params: params)
  end

  def is_authorized?
    if logged_in?
      redirect_to logout_url and return unless current_user.is_authorized?
    end
  end

  def current_tab
    @current_tab = params[:navtab].blank? ? nil : params[:navtab]
  end

  # login_required is defined in lib/authenticated_system.rb

  def admin_login_required
    if !(logged_in? && current_user.user_role.can_administer_users)
      redirect_to :controller => 'admin', :action => 'index'
    end
  end

  def can_text
    if !(logged_in? && current_user.user_role.can_manage_text)
      redirect_to :controller => 'admin', :action => 'index'
    end
  end

  def can_moderate
    if !(logged_in? && current_user.user_role.can_moderate_articles)
      redirect_to :controller => 'admin', :action => 'index'
    end
  end

  def can_blog
    unless (logged_in? && current_user.user_role.can_blog)
      redirect_to :controller => 'admin', :action => 'index'
    end
  end

  def can_stats
    unless (logged_in? && current_user.user_role.can_see_stats)
      redirect_to :controller => 'admin', :action => 'index'
    end
  end

  def no_users
    unless (logged_in? && current_user.user_role.name != "User")
      flash[:notice] = "Permission Denied"
      redirect_to login_url
    end
  end

  def admin_logged_in?
    return (logged_in? && current_user.user_role.can_administer_users)
  end

  def prepare_tsearch_query(text)
    text = text.strip

    # remove non alphanumeric
    text = text.gsub(/[^\w\.\s\-_]+/, "")

    # replace multiple spaces with one space
    text = text.gsub(/\s+/, " ")

    # replace spaces with '&'
    text = text.gsub(/ /, "&")

    text
  end

  def site_text_params_string(prms)
    ['action', 'controller', 'id', 'person_type', 'commentary_type'].collect{|k|"#{k}=#{prms[k]}" }.join("&")
  end

  def get_site_text_page
    page_params = site_text_params_string(params)

    @site_text_page = SiteTextPage.find_by(page_params: page_params)
    @site_text_page = OpenStruct.new if @site_text_page.nil?
  end

  def render_404(exception = nil)
    if exception
      logger.info "Rendering 404 with exception: #{exception.message}"
    end

    respond_to do |format|
      format.html { render :file => "public/404.html", :status => :not_found, :layout => false }
      format.xml  { head :not_found }
      format.any  { head :not_found }
    end
  end

  def set_simple_comments
    @simple_comments = false
  end

  def comment_env
    {
      :referrer => request.referer,
      :ip_address => request.remote_ip,
      :user_agent => request.user_agent,
      :permalink => request.env['HTTP_REFERER'],
      :user => current_user
    }
  end

  def news_blog_count(count)
    return nil if count.blank?
    if count >= 1000
      "#{(count/1000).floor}K"
    else
      count
    end
  end

  def random_key
    Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end

  def force_fb_cookie_delete
    cookies.delete fb_cookie_name
    set_fb_cookie(nil,nil,nil,nil)
  end

  def last_updated
    @updated_at = CongressSession.order(["date desc nulls last"]).first.updated_at rescue Time.at(0)
  end

  def cache_control
    unless logged_in?
      # Wow! expires_in is horrible. It deletes the :private key always -- source here: http://apidock.com/rails/v3.0.9/ActionController/ConditionalGet/expires_in
      expires_in 0.seconds, :public => true
    end
  end

  # Redirect to the referrer or to the passed default.
  def redirect_back_by_referer_or_default(default, options = {})
    destination = request.referer || default
    if options.delete(:uncacheable) == true
      destination += (destination =~ /\?/) ? '&' : '?'
      destination += Time.now.tv_sec.to_s
    end
    redirect_to(destination, options)
  end

  protected

  ##
  # This renders XML templates (.xml.builder) if you don't want
  # to provide an explicit template file argument in :action
  #
  def render_xml(opts={})
    request.format = 'xml'
    respond_to {|format| format.xml {render(opts)}}
  end

  def clear_return_to
    session.delete(:return_to) rescue nil
  end

  def dump_session
    logger.info session.to_yaml
  end

  def log_error(exception) #:doc:
    if ActionView::TemplateError === exception
      logger.fatal(exception.to_s)
    else
      logger.fatal(
        "\n\n[#{Time.now.to_s}] #{exception.class} (#{exception.message}):\n    " +
        clean_backtrace(exception).join("\n    ") +
        "\n\n"
      )
    end
  end

  def maintenance
    notice = "OpenCongress is performing database maintenance. Login is currently disabled."
    if !!(request.path =~ /^\/signup/)
      flash[:notice] = notice
      redirect_back_or_default('/') and return
    end
    if logged_in?
      @was_logged_in = true
    end
    if logged_in? && !(request.path =~ /^\/logout/)
      redirect_to '/logout' and return
    end
    yield
    if @was_logged_in && !!(request.path =~ /^\/logout/)
      flash[:notice] = notice
    end
  end

  def warn_geocode
    flash.now[:error] = "We are currently experiencing geocoding errors; Contacting your reps is unavailable."
  end

  def parse_caller(at)
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file   = Regexp.last_match[1]
      line   = Regexp.last_match[2].to_i
      method = Regexp.last_match[3]
      [file, line, method]
    end
  end

end
