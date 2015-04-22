require_dependency 'ipaddr'

class IndexController < ApplicationController
  layout "frontpage"

  caches_page :pipa

  include ActionView::Helpers::TextHelper

  before_filter :require_type_param, :only => [:hp_recent, :hp_popular]

  def require_type_param
    render_404 and return if not params[:type]
  end

  def index
    @sessions = CongressSession.sessions(@updated_at.to_date)
    @searches = Search.top_search_terms(10).select{ |s| (s.text.length > 2) && (s.text.split(/\s+/).length <= 2) }[0..4]
    @popular_bills = ObjectAggregate.popular('Bill', Settings.default_count_time, 4)
    @recent_votes = RollCall.order("date DESC").first(4)
    @popular_legislators = ObjectAggregate.popular('Person', Settings.default_count_time, 3)

    respond_to do |format|
      format.html { render 'interim_index' }
    end
  end

  def hp_recent
    respond_to do |format|
      format.html do
        @type = params[:type]
        case @type.to_sym
        when :bills
          @objects = Bill.recently_acted.limit(params.fetch(:limit, 4))
          @more_url = url_for(:controller => :bill, :action => :all)
          render_recent 'bill'
        when :votes
          @objects = RollCall.order("date DESC").first(params.fetch(:limit, 4))
          @more_url = url_for(:controller => :roll_call, :action => :all)
          render_recent 'vote'
        end
      end
    end
  end

  def hp_popular
    respond_to do |format|
      format.html do
        @type = params[:type]
        case @type.to_sym
        when :bills
          @objects = ObjectAggregate.popular('Bill', Settings.default_count_time, 4)
          @more_url = url_for(:controller => :bill, :action => :popular)
          render_popular 'bill'
        when :votes
          @objects = ObjectAggregate.popular('RollCall', Settings.default_count_time, 4)
          @more_url = url_for(:controller => :roll_call, :action => :all)
          render_popular 'vote'
        when :senators
          @objects = ObjectAggregate.popular('Senator', Settings.default_count_time, 4)
          @more_url = url_for(:controller => :people, :action => :senators)
          render_popular 'person'
        when :representatives
          @objects = ObjectAggregate.popular('Representative', Settings.default_count_time, 4)
          @more_url = url_for(:controller => :people, :action => :representatives)
          render_popular 'person'
        when :issues
          @objects = ObjectAggregate.popular('Subject', Settings.default_count_time, 4)
          @more_url = url_for(:controller => :issues, :action => :index)
          render_popular 'issue'
        end
      end
    end
  end

  def localized_search_placeholder
    ip = IPAddr.new(request.remote_ip).to_i
    geoip = GeoIp.where("start_ip <= ? and end_ip >= ?", ip, ip).first
    @legislators = []
    if geoip
      @legislators = Person.legislator.in_state(geoip.state).where("people.district = ? or people.title = 'Sen.'", geoip.district.to_s).all
    end
    ## Uncomment below for demo results
    # if @legislators.empty?
    #   @legislators = ObjectAggregate.popular('Person', Settings.default_count_time, 3)
    # end
    respond_to do |format|
      format.json { render :json => {:legislators => @legislators.as_json(:only => [:bioguideid, :firstname, :lastname, :state, :district])}}
    end
  end

  def pipa
  end

  def about
    redirect_to :controller => 'about'
  end

  def popular
    render :update do |page|
      page.replace_html 'popular', :partial => "index/popular", :locals => {:object => @object}
    end
  end

  def s1796_redirect
    redirect_to bill_path('111-s1796')
  end

  def senate_health_care_bill_111
    @page_title = 'Senate Health Care Bill - Health Care Reform'
    render :layout => 'application'
  end

  def senate_health_care_bill_111
    @page_title = 'The President\'s Proposal - Health Care Reform'
    render :layout => 'application'
  end

  def house_reconciliation
    @page_title = 'Health Care Bill Text - H.R. 4872 - Reconciliation Act of 2010'
    render :layout => 'application'
  end

  def close_banner
    session[:banner_cookie] = true
    redirect_to request.env["HTTP_REFERER"]
  end

  protected

  def render_popular(type)
    if @objects.any?
      render(:partial => "superlative", :locals => { :partial => "index/superlatives/#{type}", :layout => false, :collection => @objects, :as => type.to_sym, :locals => {:superlative => :popular }})
    else
      render(:text => "<p>No popular #{pluralize(0, type).sub('0 ', '')} to show.</p>".html_safe)
    end
  end

  def render_recent(type)
    if @objects.any?
      result = render(:partial => "superlative", :locals => { :partial => "index/superlatives/#{type}", :layout => false, :collection => @objects, :as => type.to_sym, :locals => {:superlative => :recent }})
    else
      render(:text => "<p>No recent #{pluralize(0, type).sub('0 ', '')} to show.</p>".html_safe)
    end
  end

end
