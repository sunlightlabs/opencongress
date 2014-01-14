class SearchController < ApplicationController
  include ActionView::Helpers::TextHelper

  def index
    @page_title = "Search OpenCongress"
  end

  def tips
    @page_title = "Search Tips"
  end

  def result
    query_string = @query = truncate(params[:q], :length => 255)
    @page_title = "Search Results: #{@query}"
    @page = (params[:page] || 1).to_i
    @found_items = 0
    congresses = @congresses = params[:search_congress] ? params[:search_congress].keys : Settings.available_congresses
    @per_page = params[:per_page] || 10
    @item_count = 0

    if @query.length == 0
      flash.now[:notice] = "You didn't enter anything in the search field!"
    elsif @query.length <= 3
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
      @search_issues = params[:search_issues] ? true : false

      if @search_people
        @people_found = Person.search(:load => true, :per_page => @per_page, :page => @page) do
          query do
            string query_string
          end
          filter :terms, :congresses_active => congresses
        end
        @people = @people_found.results
        @item_count += @people_found.total_count
      else
        @people = []
      end

      if @search_bills
        # TODO: Finish full text search
        @bills_found = Bill.search(:load => true, :page => @page, :per_page => @per_page) do
          query do
            string query_string
          end
          filter :terms, :congress => congresses
        end
        @bills = @bills_found.results
        @item_count += @bills_found.total_count
      else
        @bills = []
      end

      if @search_committees
        @committees_found = Committee.search(:load => true, :page => @page, :per_page => @per_page) do
          query do 
            string query_string
          end
        end
        @committees = @committees_found.results.sort_by { |c| [(c.name || ''), (c.subcommittee_name || '')] }
                                               .group_by(&:name)
        @item_count += @committees_found.total_count
      end

      if @search_issues
        @issues_found = Subject.search(@query, :page => @page, :per_page => @per_page)
        @issues = @issues_found.results
        @item_count += @issues_found.total_count
      end

      # TODO: Add search over Commentary, which includes news and blogs

      if @item_count == 0
        flash.now[:notice] = "Sorry, your search returned no results."
      end
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
