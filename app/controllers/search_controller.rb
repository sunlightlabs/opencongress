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
                            :search_filters => params.select {|p,v| Search.search_filter_list.include?(p.to_sym) && v.to_i == 1 }.keys,
                            :search_congresses => params[:search_congress] ? params[:search_congress].keys : ["#{Settings.default_congress}"])

    if @search.valid? && @search.reload

      # store search in session cache if it isn't there already
      unless session[:searched_terms] and session[:searched_terms].index(@search.search_text)
        session[:searched_terms] = '' unless session[:searched_terms]
        session[:searched_terms] += "#{@search.search_text} "
      end

      # set search filters
      set_search_filters
      # retrieve search results
      @results = @search.initiate_search
      # set number of found items
      @found_items = @results.size
      # set template variables and return
      @page = @search.page
      @query = @search.search_text
      @congresses = @search.get_congresses
    end

  end

  def result_ajax
    result

    render :action => 'result', :layout => false
  end

  # TODO: This is so terrible guys.
  def autocomplete
    if params[:value].present?
      names = Person.where(title:%w{'Rep.','Sen.'}).collect{ |p| [p.popular_name, p.name, p] }
      #names = Person.find(:all, :conditions => "title='Rep.' OR title='Sen.'").collect{ |p| [p.popular_name, p.name, p] }

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
    @page = '1' unless @page
		@days = days_from_params(params[:days])
 		@searches = Search.top_search_terms(100,@days).paginate :page => @page
    @title_class = 'sort'
		@page_title = 'Top Search Terms'
  end

  private

  def set_search_filters
    Search.search_filter_list.each {|filter| instance_variable_set("@#{filter}", false) }
    @search.search_filters.each {|filter| instance_variable_set("@#{filter}", true) }
  end

end