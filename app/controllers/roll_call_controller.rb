class RollCallController < ApplicationController
  helper :index
  include RollCallHelper
  skip_before_filter :store_location, :except => [:show, :all]
  before_filter :page_view, :only => [:show, :by_number]
  before_filter :can_blog, :only => [:update_hot]
  before_filter :no_users, :only => [:can_blog]

  @@VOTE_TYPES = { "+" => "Aye", "-" => "Nay", "0" => "Abstain" }
  @@VOTE_VALS = @@VOTE_TYPES.invert

  @@PIE_OPTIONS = {
    :start_angle => 270,
    :no_labels => true,
    # :tip => "#label#\n(Click for Details)",
    :tip => "#label#",
    :gradient_fill => false
  }

  def master_piechart_data
    @roll_call = RollCall.find_by_id(params[:id])
    render_404 and return unless @roll_call
    @vote_counts = @roll_call.roll_call_votes.group(:vote).count

    color_well = [
      '#16CEC6',
      '#DF18DF',
      '#319450',
      '#E0D81A'
    ].cycle
    colors = []
    vals = []

    @vote_counts.each do |vote_type, cnt|
      vals << OFC2::PieValue.new(:value => cnt,
                                 :label => "#{vote_name(vote_type)} (#{cnt})",
                                 :on_click => "openRollCallOverlay('#{vote_name_suitable_for_id(vote_name(vote_type))}_All')")

      if ['Aye', 'Yea', '+'].include?(vote_type)
        colors << '#4ED046'
      elsif ['No', 'Nay', '-'].include?(vote_type)
        colors << '#F53C34'
      else
        colors << color_well.next
      end
    end

    pie = OFC2::Pie.new(
      @@PIE_OPTIONS.merge({
        :alpha => 0.8,
        :animate => [OFC2::PieFade.new, OFC2::PieBounce.new],
        :values => vals,
        :radius => 80
      })
    )
    pie_shadow = OFC2::Pie.new(
      @@PIE_OPTIONS.merge({
        :alpha => 0.5,
        :shadow => true,
        :values => vals,
        :radius => 80
      })
    )
    pie.colours = colors
    chart = OFC2::Graph.new
    chart.title= OFC2::Title.new( :text => "#{@roll_call.chamber.capitalize} Roll Call ##{@roll_call.number}" , :style => "{font-size: 14px; color: #b50F0F; text-align: center;}")
    chart << pie_shadow
    chart << pie
    chart.bg_colour = '#FFFFFF'

    render :text => chart.render
  end

  def partyvote_piechart_data
    @roll_call = RollCall.find_by_id(params[:id])
    render_404 and return unless @roll_call
    radius = params[:radius] ||= 80
    votes = @roll_call.roll_call_votes.select { |rcv| rcv.vote == params[:breakdown_type] }

    disclaimer_note = params[:disclaimer_off].blank? ? "**" : ""

    democrat_votes = votes.select { |rcv| rcv.person.party == 'Democrat' if rcv.person }
    republican_votes = votes.select { |rcv| rcv.person.party == 'Republican' if rcv.person }
    other_votes_size = votes.size - democrat_votes.size - republican_votes.size

    vals = []
    colors = []

    if republican_votes.size > 0
      vals << OFC2::PieValue.new(:value => republican_votes.size,
                                 :label => "Republican (#{republican_votes.size})",
                                 :on_click => "openRollCallOverlay('#{vote_name_suitable_for_id(vote_name(params[:breakdown_type]))}_Republican')")
      colors << "#F84835"
    end

    if democrat_votes.size > 0
      vals << OFC2::PieValue.new(:value => democrat_votes.size,
                                 :label => "Democrat (#{democrat_votes.size})",
                                 :on_click => "openRollCallOverlay('#{vote_name_suitable_for_id(vote_name(params[:breakdown_type]))}_Democrat')")
      colors << "#5D77DA"
    end

    if other_votes_size > 0
      vals << OFC2::PieValue.new(:value => other_votes_size,
                                 :label =>"Other (#{other_votes_size})",
                                 :on_click => "openRollCallOverlay('#{vote_name_suitable_for_id(vote_name(params[:breakdown_type]))}_Other')")
      colors << "#DDDDDD"
    end

     pie = OFC2::Pie.new(
      @@PIE_OPTIONS.merge({
        :alpha => 0.8,
        :animate => [OFC2::PieFade.new, OFC2::PieBounce.new],
        :values => vals,
        :radius => radius
      })
    )
    pie_shadow = OFC2::Pie.new(
      @@PIE_OPTIONS.merge({
        :alpha => 0.5,
        :shadow => true,
        :animate =>  [OFC2::PieFade.new, OFC2::PieBounce.new],
        :values => vals,
        :radius => radius
      })
    )
    pie.colours = colors
    chart = OFC2::Graph.new
    chart.title = OFC2::Title.new(:text => "#{vote_name(params[:breakdown_type])} Votes: #{votes.size}#{disclaimer_note}",
                                  :style => "font-size:14px;color:#333;")
    chart << pie_shadow
    chart << pie
    chart.bg_colour = '#FFFFFF'

    render :text => chart.render
  end

  def show
    @roll_call = RollCall.find_by_id(params[:id])

    unless @roll_call
      render_404 and return
    else
      redirect_to @roll_call.vote_url
    end
  end

  def update_hot
    @roll_call = RollCall.find_by_id(params[:id])
    render_404 and return unless @roll_call
    @roll_call.is_hot = params[:roll_call][:is_hot]
    @roll_call.hot_date = Time.now if @roll_call.is_hot
    @roll_call.title = params[:roll_call][:title] if params[:roll_call][:title]
    @roll_call.save
    redirect_back_or_default("/roll_call/show/#{@roll_call.id}")
  end

  def sublist
    flash[:warning] = "The page you navigated to is no longer available. This is the page for the related roll call."
    @roll_call = RollCall.find(params[:id])
    redirect_to :action => 'by_number',
                :chamber => @roll_call.chamber.downcase[0],
                :year => @roll_call.date.year,
                :number => @roll_call.number
  end

  def index
    redirect_to :action => 'all'
  end

  def all
    @page = params[:page].blank? ? 1 : params[:page]

    if params[:sort] == 'majorbills'
      @sort = 'majorbills'
      @rolls = RollCall.on_major_bills_for(Settings.default_congress)
                       .paginate(:page => @page)
    else
      @sort = 'allvotes'
      @rolls = RollCall.in_congress(Settings.default_congress)
                       .includes(:bill, :amendment)
                       .order('date DESC')
                       .paginate(:page => @page)
    end
    @carousel = [ObjectAggregate.popular('RollCall', Settings.default_count_time).slice(0..9)]

    @page_title = 'All Roll Calls'
    @title_desc = SiteText.find_title_desc('roll_call_all')

    @atom = {'link' => url_for(:only_path => false, :controller => 'roll_call', :action => 'atom'), 'title' => "Recent Roll Calls"}
  end

  def search
    @roll_query = params[:q]

    query_stripped = prepare_tsearch_query(@roll_query)

    @rolls = RollCall.find_by_sql(
                ["SELECT roll_calls.* FROM roll_calls, bills, bill_fulltext
                               WHERE bills.session=? AND
                                     bill_fulltext.fti_names @@ to_tsquery('english', ?) AND
                                     bills.id = bill_fulltext.bill_id AND
                                     roll_calls.bill_id=bills.id
                               ORDER BY bills.hot_bill_category_id, roll_calls.date DESC", Settings.default_congress, query_stripped]
                              )

     render :partial => 'roll_calls_list', :locals => { :rolls => @rolls }, :layout => false
  end

  def atom
    @rolls = RollCall.find :all, :order => 'date DESC', :limit => 20
    expires_in 60.minutes, :public => true

    render :layout => false
  end

  def compare_two_rolls
    @roll_call1 = RollCall.find_by_ident(params[:vote1])
    @roll_call2 = RollCall.find_by_ident(params[:vote2])

    unless @roll_call1.where == @roll_call2.where
      flash[:error] = "Can't compare roll calls in different chambers!"
      redirect_to :action => 'index'
      return
    end

    first_vote_condition = params[:first_vote].nil? ? "" : " AND roll_call1.vote = '#{@@VOTE_VALS[params[:first_vote]]}' "

    @people = Person.find_by_sql(["SELECT people.*, roll_call1.vote as vote1, roll_call2.vote as vote2
                                  FROM people
                                  INNER JOIN
                                    (SELECT roll_call_votes.* FROM roll_call_votes
                                     WHERE roll_call_votes.roll_call_id = ?) roll_call1 ON roll_call1.person_id = people.id
                                  INNER JOIN
                                    (SELECT roll_call_votes.* FROM roll_call_votes
                                     WHERE roll_call_votes.roll_call_id = ?) roll_call2 ON roll_call2.person_id = people.id
                                  WHERE roll_call1.vote <> roll_call2.vote #{first_vote_condition}
                                  ORDER BY people.lastname",
                                 @roll_call1.id, @roll_call2.id])
    @page_title = "Comparing #{@roll_call1.where.capitalize} Vote ##{@roll_call1.number} to ##{@roll_call2.number}"
  end

  def summary_text
    @roll_call = RollCall.find_by_ident(params[:id])
    render_404 and return unless @roll_call

    render :layout => false
  end

  def by_number
    @vote_counts = @roll_call.roll_call_votes.group(:vote).count
    @party_vote_counts = @roll_call.roll_call_votes.includes(:person).group(:vote, :party).count
    @titles_by_person = Hash[ Person.on_date(@roll_call.date).collect{ |p| [p.id, p.role_type] } ]

    if params[:state] && State.for_abbrev(params[:state])
      @state_abbrev = params[:state]
      @state_name = State.for_abbrev(params[:state])
    end

    roll_call_shared

    render :action => 'show'
  end

  private

  def page_view
    if params[:id]
      @roll_call = RollCall.find_by_id(params[:id])
    elsif params[:year] and params[:chamber] and params[:number]
      chamber_name = case params[:chamber]
                     when 'h' then 'house'
                     when 's' then 'senate'
                     else params[:chamber]
                     end
      @roll_call = RollCall.in_year(params[:year].to_i)
                           .where(:where => chamber_name,
                                  :number => params[:number].to_i).first
      if @roll_call.nil?
        flash[:warning] = "No such roll call."
        render_404 and return
      end
    else
      notfound
    end

    if @roll_call
      key = "page_view_ip:RollCall:#{@roll_call.id}:#{request.remote_ip}"
      unless read_fragment(key)
        @roll_call.page_view
        write_fragment(key, "c", :expires_in => 1.hour)
      end
    end
  end

  def roll_call_shared
    @master_chart = ofc2(400,220, "roll_call/master_piechart_data/#{@roll_call.id}")

    @page_title = @roll_call.title.blank? ? "" : "#{@roll_call.title} - "
    @page_title += "#{@roll_call.chamber} Roll Call ##{@roll_call.number} Details"

    @title_desc = SiteText.find_title_desc('roll_call_show')
  end
end
