class CommitteeController < ApplicationController
  before_filter :page_view, :only => :show

  def index
    @committees = Committee.where(:parent_id => nil)
    @house_committees = Committee.where(:chamber => 'house',
                                        :parent_id => nil,
                                        :active => true)
                                 .order(:name, :subcommittee_name)
    @senate_committees = Committee.where(:chamber => 'senate',
                                         :parent_id => nil,
                                         :active => true)
                                  .order(:name, :subcommittee_name)

    # @carousel = ObjectAggregate.popular('Committee', Settings.default_count_time).slice(0..7)

    @page_title =  "Committees"
    @title_class = "sort"
    @title_desc = SiteText.find_title_desc('committee_index')

  end

  def show
    if @committee.has_wiki_link? # && !Rails.env.production?
      @wiki_tab = true
      @wiki_url = @committee.wiki_url
    end

    @main = Committee.find_by_name_and_subcommittee_name(@committee.name, nil)
    unless @main
      redirect_to :action => 'nodata'
      return
    end
    @reports = @committee.reports.sort do |a, b|
      if a.reported_at.nil?
        -1
      elsif b.reported_at.nil?
        1
      else
        (a.reported_at - b.reported_at).to_i
      end
    end.reverse.first(5)

    @chair = @committee.chair
    @ranking_member = @committee.ranking_member
    @vice_chair = @committee.vice_chair
    @members = @committee.members.order(:lastname).select do |p|
      not [@chair, @ranking_member, @vice_chair].include? p
    end

    @bills_sponsored = @committee.bills_sponsored(5)
 	 	@title_class = "tabs"
 	 	@page_title_prefix = "U.S. Congress"
    @page_title = @committee.main_committee_name
		@stats_object = @user_object = @comments = @committee

    @atom = {'link' => url_for(:only_path => false, :controller => 'committee', :id => @committee, :action => 'atom'), 'title' => "#{@committee.name} - Major Bill Actions"}
  end

  def by_chamber
    case params[:chamber]
    when 'house'
      @page_title = "House Committees"
    when 'senate'
      @page_title = "Senate Committees"
    when nil
      redirect_to :action => 'index'
    else
      raise ActionController::RoutingError.new('No such chamber')
    end

    @committees = Committee.where(:chamber => params[:chamber], :parent_id => nil, :active => true)

    @related_committees = ObjectAggregate.popular('Committee', Settings.default_count_time).slice(0..2) unless @custom_sidebar

    @title_class = "sort"
    @title_desc = SiteText.find_title_desc('committee_index')

  end

  def by_most_viewed
    @sort = 'popular'

    @days = days_from_params(params[:days])

    @committees = ObjectAggregate.popular('Committee', @days)

    @atom = {'link' => url_for(:only_path => false, :controller => 'committee', :action => 'atom_top20'), 'title' => "Top 20 Most Viewed Committees"}

    @page_title = "Most Viewed Committees"
    @title_class = "sort"
    @title_desc = SiteText.find_title_desc('committee_index')
  end

  def report
    #This way things show up in our logs.
    redirect_to CommitteeReport.find(params[:id]).gpo_url
  end

  def atom
    @committee = Committee.find(params[:id])

    @committee_name = @committee.subcommittee_name ? @committee.subcommittee_name : @committee.name
    @actions = @committee.latest_major_actions(20)
    expires_in 60.minutes, :public => true

    render 'atom.xml', :layout => false
  end

  def atom_top20
    @comms = Committee.top20_viewed
    expires_in 60.minutes, :public => true

    render :action => 'top20_atom.xml', :layout => false
  end

  def nodata
    @page_title = "Committee Data Forthcoming"

  end

  private

  def page_view
    @committee = Committee.find(params[:id], :include => :reports)

    if @committee
      key = "page_view_ip:Committee:#{@committee.id}:#{request.remote_ip}"
      unless read_fragment(key)
        @committee.increment!(:page_views_count)
        @committee.page_view
        write_fragment(key, "c", :expires_in => 1.hour)
      end
    end
  end
end
