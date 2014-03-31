class IssueController < ApplicationController
  before_filter :issue_profile_shared, :only => [:show, :comments, :defunct]
  before_filter :page_view, :only => :show

  PER_PAGE = 1000

  def index
    @filter_by = :active
    @subjects = Subject.active.where("subjects.bill_count > 0").order(["subjects.bill_count desc", "subjects.term asc"]).paginate(:page => params[:page])
    @page_title = "Active Issues"
    include_carousel
  end

  def most_viewed
    @filter_by = :views
    @days = days_from_params(params[:days])
    @order = :most_viewed
    @subjects = ObjectAggregate.popular('Subject', @days).paginate
    @atom = {'link' => url_for(:only_path => false, :controller => 'issue', :action => 'atom_top20'), 'title' => "Top 20 Most Viewed Issues"}
    @page_title = "Most Viewed Issues"
    @title_class = "sort"
    @title_desc = SiteText.find_title_desc('issue_index')

    render :action => 'index'
  end

  def all
    redirect_to all_issues_path('A') and return unless params[:id].present?

    @filter_by = :all
    # @subjects = Subject.order("term ASC").paginate(:page => (params[:page] || 1 rescue 1).to_i,
    #                                                :per_page => PER_PAGE)
    @subjects = Subject.find_by_first_letter params[:id]
    @page_title = "All Issues starting with '#{params[:id]}'"
    include_carousel

    render "index"
  end

  def quick_search
    @q = params[:q]

    unless @q.nil?
      query_stripped = prepare_tsearch_query(@q)

      @subjects = Subject.full_text_search(query_stripped, { :page => params[:page],
                                                             :per_page => PER_PAGE})
    end

    render :layout => false
  end

  def comments
    id = params[:id].to_i
    @subject = Subject.find_by_id(id)
    unless @subject
       render_404 and return
    end
    congress = params[:congress] ? params[:congress] : Settings.default_congress
      respond_to do |format|
        format.html {
    @sidebar_stats_object = @subject
    @user_object = @subject
    @page_title_prefix = "U.S. Congress"
    @page_title = @subject.term
    @title_class = "tabs"
    @comments = @subject

          @current_tab = "comments"

          comment_redirect(params[:goto_comment]) and return if params[:goto_comment]

    @atom = {'link' => url_for(:only_path => false, :controller => 'issue', :id => @subject, :action => 'atom'), 'title' => "Major Bill Actions in #{@subject.term}"}
		@hide_atom = true

        }
      end
  end

  def show
    unless @subject
       render_404 and return
    end

    comment_redirect(params[:goto_comment]) and return if params[:goto_comment]

    @sidebar_stats_object = @subject
    @user_object = @subject
    @page_title_prefix = "U.S. Congress"
    @page_title = @subject.term
    @meta_description = "#{@subject.term}-related bills and votes in the U.S. Congress."
    @comments = @subject

    @latest_bills = @subject.latest_bills(3, 1)
    @major_bills = @subject.major_bills.where(:session => Settings.default_congress)
    @key_votes = @subject.key_votes
    @groups = @subject.groups.all
    @passed_bills = @subject.passed_bills(3, 1, Settings.available_congresses)

    @atom = {'link' => url_for(:only_path => false, :controller => 'issue', :id => @subject, :action => 'atom'), 'title' => "Major Bill Actions in #{@subject.term}"}
		@hide_atom = true
		@tracking_suggestions = @subject.tracking_suggestions
  end

  def defunct
    unless @subject
       render_404 and return
    end

    @sidebar_stats_object = @subject
    @user_object = @subject
    @page_title_prefix = "U.S. Congress"
    @page_title = "#{@subject.term}"
    @meta_description = "#{@subject.term}-related bills and votes in previous sessions of the U.S. Congress."
    @comments = @subject
    if params[:filter] == 'enacted'
      @bills = @subject.passed_bills(10, params[:page].blank? ? 1 : params[:page].to_i,
                                     Settings.available_congresses - [Settings.default_congress])
    else
      @bills = @subject.latest_bills(10, params[:page].blank? ? 1 : params[:page].to_i,
                                    Settings.available_congresses - [Settings.default_congress])
    end
    @atom = {'link' => url_for(:only_path => false, :controller => 'issue', :id => @subject, :action => 'atom'), 'title' => "Major Bill Actions in #{@subject.term}"}
		@hide_atom = true
		@tracking_suggestions = @subject.tracking_suggestions
  end

  def top_twenty_bills
    @subject = Subject.find(params[:id])
    @bills = @subject.latest_bills(20)

    @page_title = "#{@subject.term} - Recent Bills"

  end

  def top_viewed_bills
   @subject = Subject.find(params[:id])
   @bills = @subject.most_viewed_bills(20)
   @page_title = "#{@subject.term} - Most Viewed Bills"

  end

  def atom
    @subject = Subject.find(params[:id])

    @actions = @subject.latest_major_actions(20)
    expires_in 60.minutes, :public => true

    render :layout => false
  end

  def atom_top20
    @issues = Subject.top20_viewed
    expires_in 60.minutes, :public => true

    render :action => 'top20_atom', :layout => false
  end

  private

  def include_carousel
    @carousel = [ObjectAggregate.popular('Subject', Settings.default_count_time).slice(0..9)]
  end

  def issue_profile_shared
    id = params[:id].to_i

    if @subject = Subject.find_by_id(id)
      @page_title_prefix = "U.S. Congress"
      @page_title = @subject.term
      @meta_description = "#{@subject.term} on OpenCongress"
      @sidebar_stats_object = @user_object = @comments = @subject
      @page = params[:page] ||= 1
      @atom = {'link' => url_for(:only_path => false, :controller => 'issue', :id => @subject, :action => 'atom'), 'title' => "#{@subject.term} activity"}
    else
      flash[:error] = "Invalid bill URL."
      redirect_to :action => 'index'
    end
  end

  def page_view
    if @subject
      key = "page_view_ip:Subject:#{@subject.id}:#{request.remote_ip}"
      unless read_fragment(key)
        @subject.increment!(:page_views_count)
        @subject.page_view
        write_fragment(key, "c", :expires_in => 1.hour)
      end
    end
  end
end
