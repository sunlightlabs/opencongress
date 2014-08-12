class SearchController < ApplicationController
  include ActionView::Helpers::TextHelper

  def index
    @page_title = 'Search OpenCongress'
  end

  def tips
    @page_title = 'Search Tips'
  end

  def result

    @search = Search.create(:search_text => params[:q],
                            :page => params[:page],
                            :user => current_user == :false ? nil : current_user,
                            :search_filters => params.select {|p,v| Search::SEARCH_FILTER_CODE_MAP.include?(p.to_sym) && v.to_i == 1 }.keys,
                            :search_congresses => params[:search_congress] ? params[:search_congress].keys : ["#{Settings.default_congress}"])

    if @search.valid? && @search.reload()

      # store search in session cache if it isn't there already
      unless session[:searched_terms] and session[:searched_terms].index(@search.search_text)
        session[:searched_terms] = "" unless session[:searched_terms]
        session[:searched_terms] += "#{@search.search_text} "
      end

      # set search filters
      set_search_filters()

      # initialize found items to 0 before running through filters
      @found_items = 0

      if @search_bills
        # first see if we match a bill's title exactly
        bill_titles = BillTitle.find(:all, :conditions => [ "UPPER(title)=?", @search.search_text.upcase ])
        bills_for_title = bill_titles.collect {|bt| bt.bill }
        bills_for_title.uniq!

        # if we match only one then go directly to that bill
        if bills_for_title.size == 1
          redirect_to bill_path(bills_for_title[0])
          return
        end

        # otherwise search bills for the text
        @bills = Bill.full_text_search(@search.search_text, { :page => @search.page, :congresses => @search.get_congresses() })
        @found_items += @bills.total_entries
      end

      if @search_people
        if !(@search.search_text =~ /^[\d]{5}(-[\d]{4})?$/).nil?
          # TODO: Why does this return nil, and are there implications to making it return []?
          @people = (Person.find_current_congresspeople_by_zipcode(*@search.search_text.split('-')).flatten rescue []).paginate(:per_page => 9, :page => @search.page)
        else
          people_for_name = Person.find(:all,
                                        :conditions => [ "(UPPER(firstname || ' ' || lastname)=? OR
                                      UPPER(nickname || ' ' || lastname)=?)",
                                                         @search.search_text.upcase, @search.search_text.upcase ])
          redirect_to person_url(people_for_name[0]) and return if people_for_name.size == 1

          opts = {:page => @search.page}
          # restrict search if the only congress checked is the current congress
          opts[:only_current] = true
          opts[:only_current] = false if params.fetch(:search_congress, {}).keys != [Settings.default_congress.to_s]

          @people = Person.full_text_search(@search.search_text, opts)
        end
        @found_items += @people.total_entries
      end

      if @search_committees
        @committees = Committee.full_text_search(@search.search_text).select{ |c| c.active? }
        @found_items += @committees_total = @committees.size
        @committees = @committees.sort_by { |c| [(c.name || ""), (c.subcommittee_name || "") ] }.group_by(&:name)
      end

      if @search_issues
        @issues = Subject.full_text_search(@search.search_text, :page => @search.page)
        @found_items += @issues.total_entries
      end

      if @search_comments
        @comments = Comment.full_text_search(@search.search_text, { :page => @search.page, :congresses => @search.get_congresses() })
        @found_items += @comments.total_entries
      end

      if @search_commentary || @search_news
        @news = Commentary.full_text_search(@search.search_text, { :page => @search.page, :commentary_type => 'news' })
        @found_items += @news.total_entries
      end

      if @search_commentary || @search_blogs
        @blogs = Commentary.full_text_search(@search.search_text, { :page => @search.page, :commentary_type => 'blog' })
        @found_items += @blogs.total_entries
      end

      if @search_gossip_blog
        @articles = Article.full_text_search(@search.search_text, :page => @search.page)
        @found_items += @articles.total_entries
      end

      if @found_items == 0
        if (@search.get_congresses() == ["#{Settings.default_congress}"])
          msg = "Sorry, your search returned no results in the current #{Settings.default_congress}th Congress."
        else
          msg = 'Sorry, your search returned no results.'
        end
        flash.now[:error] = msg
      end

      # set template variables and return
      @page = @search.page
      @query = @search.search_text
      @congresses = @search.get_congresses()
      return

    else
      return
    end

  end

  def result_ajax
    result

    render :action => 'result', :layout => false
  end

  # TODO: This is so terrible guys.
  def autocomplete
    if params[:value].present?
      names = Person.find(:all, :conditions => "title='Rep.' OR title='Sen.'").collect{ |p| [p.popular_name, p.name, p] }

      bill_titles = []
      bills = Bill.major
      bills.each do |bill|
        bill_titles << [ bill.title_full_common, bill.title_full_common, bill ]
      end

      @people_hits = names.select{|h| h[0] =~ /#{Regexp.escape(params[:value])}/i }
      @bill_hits = bill_titles.select{|h| h[0] =~ /#{Regexp.escape(params[:value])}/i }
    else
      @people_hits = []
      @bill_hits = []
    end
    render :layout => false
  end

  def popular
    @page = params[:page]
    @page = "1" unless @page
		@days = days_from_params(params[:days])
 		@searches = Search.top_search_terms(100,@days).paginate :page => @page
    @title_class = "sort"
		@page_title = "Top Search Terms"
  end

  private

  def set_search_filters
    Search::SEARCH_FILTERS_LIST.each {|filter| instance_variable_set("@#{filter}", false) }
    @search.search_filters.each {|filter| instance_variable_set("@#{filter}", true) }
  end

end
