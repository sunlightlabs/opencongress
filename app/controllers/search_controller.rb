class SearchController < ApplicationController
  include ActionView::Helpers::TextHelper

  def index
    @page_title = "Search OpenCongress"
  end

  def tips
    @page_title = "Search Tips"
  end

  def result
    @query = truncate(params[:q], :length => 255)
    @page_title = "Search Results: #{@query}"
    @page = (params[:page] || 1).to_i
    @found_items = 0
    @congresses = params[:search_congress] ? params[:search_congress].keys : ["#{Settings.default_congress}"]
    @per_page = params[:per_page] || 10

    if @query
      @people_found = Person.search(@query, :load => true, :per_page => @per_page)
      @bills_found = Bill.search(@query, :load => true, :per_page => @per_page)
    else
      query_stripped = prepare_tsearch_query(@query)

      if (query_stripped.size == 0)
        flash.now[:notice] = "You didn't enter anything meaningful into the search field!"
      elsif (query_stripped.size < 4 && !query_stripped.to_i)
        flash.now[:notice] = "Your query must be longer than three characters!"
      else
        # save the search - but only once per session
        unless session[:searched_terms] and session[:searched_terms].index(@query)
          Search.create(:search_text => @query)
          session[:searched_terms] = "" unless session[:searched_terms]
          session[:searched_terms] += "#{@query} "
        end

        @search_bills = params[:search_bills] ? true : false
        @search_people = params[:search_people] ? true : false
        @search_committees = params[:search_committees] ? true : false
        @search_industries = false
        @search_issues = params[:search_issues] ? true : false
        @search_news = params[:search_news] ? true : false
        @search_blogs = params[:search_blogs] ? true : false
        @search_commentary = params[:search_commentary] ? true : false
        @search_comments = false
        @search_gossip_blog = params[:search_gossip_blog] ? true : false

        @search_commentary = false # temporary

        if (@search_bills)
          # first see if we match a bill's title exactly
          bill_titles = BillTitle.find(:all, :conditions => [ "UPPER(title)=?", query_stripped.upcase ])
          bills_for_title = bill_titles.collect {|bt| bt.bill }
          bills_for_title.uniq!

          # if we match only one, go right to that bill
          if bills_for_title.size == 1
            redirect_to bill_path(bills_for_title[0])
            return
          end

          @bills = Bill.full_text_search(query_stripped, { :page => @page, :congresses => @congresses })

          @found_items += @bills.total_entries
        end

        if (@search_people)
          if !(query_stripped =~ /^[\d]{5}(-[\d]{4})?$/).nil?
            # TODO: Why does this return nil, and are there implications to making it return []?
            @people = (Person.find_current_congresspeople_by_zipcode(*query_stripped.split('-')).flatten rescue []).paginate(:per_page => 9, :page => @page)
          else
            people_for_name = Person.find(:all,
                   :conditions => [ "(UPPER(firstname || ' ' || lastname)=? OR
                                      UPPER(nickname || ' ' || lastname)=?)",
                                      query_stripped.upcase, query_stripped.upcase ])
            redirect_to person_url(people_for_name[0]) and return if people_for_name.size == 1

            opts = {:page => @page}
            # restrict search if the only congress checked is the current congress
            opts[:only_current] = true
            opts[:only_current] = false if params.fetch(:search_congress, {}).keys != [Settings.default_congress.to_s]

            @people = Person.full_text_search(query_stripped, opts)
          end
          @found_items += @people.total_entries
        end

        if (@search_committees)
          @committees = Committee.full_text_search(query_stripped)
          @found_items += @committees_total = @committees.size


          @committees = @committees.sort_by { |c| [(c.name || ""), (c.subcommittee_name || "") ] }.group_by(&:name)
        end


        if (@search_issues)
          @issues = Subject.full_text_search(query_stripped, :page => @page)

          @found_items += @issues.total_entries
        end

        if (@search_comments)
          @comments = Comment.full_text_search(query_stripped, { :page => @page, :congresses => @congresses })

          @found_items += @comments.total_entries
        end

        if (@search_commentary || @search_news)
          @news = Commentary.full_text_search(query_stripped, { :page => @page, :commentary_type => 'news' })


          @found_items += @news.total_entries
        end

        if (@search_commentary || @search_blogs)
          @blogs = Commentary.full_text_search(query_stripped, { :page => @page, :commentary_type => 'blog' })

          @found_items += @blogs.total_entries
        end

        if (@search_gossip_blog)
          @articles = Article.full_text_search(query_stripped, :page => @page)
      flash.now[:notice] = "You didn't enter anything in the search field!"
    end

    @item_count = (@people_found.total_count
                   + @bills_found.total_count)

    if @item_count == 0
      flash.now[:notice] = "Sorry, your search returned no results."
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
end
