require_dependency 'ipaddr'

class IndexController < ApplicationController
  layout "frontpage"

  caches_page :pipa

  include ActionView::Helpers::TextHelper

  def index
    unless read_fragment("frontpage_rightside")
      @index_tabs = [
              # {:title => 'Bills in the News',
              # :partial => 'bill',
              # :collection => Bill.find_by_most_commentary('news', 5, 7.days, Settings.default_congress),
              # :id => 'bns',
              # :link => 'bill/most/news?types=all',
              # :count_type => 'news_articles'},
              # {:title => 'Bills on Blogs',
              # :partial => 'bill',
              # :collection => Bill.find_by_most_commentary('blog', 5, 7.days, Settings.default_congress),
              # :id => 'bbg',
              # :link => 'bill/most/blog?types=all',
              # :style => 'display: none;',
              # :count_type => 'blog_articles'},
              {:title => 'Most-Viewed Bills',
              :partial => 'bill',
              :collection => ObjectAggregate.popular('Bill', Settings.default_count_time, 5),
              :id => "bv",
              :link => '/bill/most/viewed',
              # :style => 'display: none;',
              :count_type => 'views'},
              {:title => 'Newest Bills',
              :partial => 'bill',
              :collection => Bill.find(:all, :order => 'introduced DESC', :limit => 5),
              :id => 'bn',
              :link => '/bill/all',
              :style => 'display: none;',
              :count_type => 'views'},
              {:title => 'Most-Viewed Senators',
              :partial => 'person',
              :collection => Person.list_chamber('sen', Settings.default_congress, "view_count desc", 5),
              :id => 'ps',
              :style => 'display: none;',
              :link => '/people/senators?sort=popular',
              :count_type => 'views'},
              {:title => 'Most-Viewed Reps',
              :partial => 'person',
              :collection => Person.list_chamber('rep', Settings.default_congress, "view_count desc", 5),
              :link => '/people/representatives?sort=popular',
              :style => 'display: none;',
              :id => 'pr',
              :count_type => 'views'},
              {:title => 'Most-Viewed Issues',
              :partial => 'issue',
              :collection => ObjectAggregate.popular('Subject', Settings.default_count_time, 5),
              :style => 'display: none;',
              :id => 'pis',
              :link => '/issues',
              :count_type => 'views'}]

    end

    unless read_fragment("frontpage_featured_members")
      @popular_sen_text = FeaturedPerson.senator
      @popular_rep_text = FeaturedPerson.representative
    end

    @sessions = CongressSession.sessions

  end

  def new
    @sessions = CongressSession.sessions
    @searches = Search.top_search_terms(4)
    @popular_bills = ObjectAggregate.popular('Bill', Settings.default_count_time, 4)
    @recent_votes = RollCall.last(4)
    @popular_legislators = ObjectAggregate.popular('Person', Settings.default_count_time, 3)

    render 'interim_index'
  end

  def hp_recent
    type = params[:type]
    case type.to_sym
    when :bills
      @objects = Bill.recently_acted.limit(params.fetch(:limit, 4))
      render_recent 'bill'
    when :votes
      @objects = RollCall.last(params.fetch(:limit, 4))
      render_recent 'vote'
    end
  end

  def hp_popular
    type = params[:type]
    case type.to_sym
    when :bills
      @objects = ObjectAggregate.popular('Bill', Settings.default_count_time, 4)
      render_popular 'bill'
    when :votes
      @objects = ObjectAggregate.popular('RollCall', Settings.default_count_time, 4)
      render_popular 'vote'
    when :senators
      @objects = ObjectAggregate.popular('Senator', Settings.default_count_time, 4)
      render_popular 'person'
    when :representatives
      @objects = ObjectAggregate.popular('Representative', Settings.default_count_time, 4)
      render_popular 'person'
    when :issues
      @objects = ObjectAggregate.popular('Subject', Settings.default_count_time, 4)
      render_popular 'issue'
    end
  end

  def localized_search_placeholder
    ip = IPAddr.new(request.remote_ip).to_i
    geoip = GeoIp.where("start_ip <= ? and end_ip >= ?", ip, ip).first
    @legislators = []
    if geoip
      @legislators = Person.in_state(geoip.state).where("district = ? or title = 'Sen.'", geoip.district.to_s).all
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

  protected

  def render_popular(type)
    if @objects.any?
      render(:partial => "index/superlatives/#{type}", :layout => false, :collection => @objects, :as => type.to_sym, :locals => {:superlative => :popular})
    else
      render(:text => "<p>No popular #{pluralize(0, type).sub('0 ', '')} to show.</p>".html_safe)
    end
  end

  def render_recent(type)
    if @objects.any?
      result = render(:partial => "index/superlatives/#{type}", :layout => false, :collection => @objects, :as => type.to_sym, :locals => {:superlative => :recent})
    else
      render(:text => "<p>No recent #{pluralize(0, type).sub('0 ', '')} to show.</p>".html_safe)
    end
  end

end
