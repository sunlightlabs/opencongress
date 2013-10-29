class DistrictsController < ApplicationController
  before_filter :get_state

  # GET /states/:state_id/districts
  def index
    @districts = @state.districts
  end

  # GET /states/:state_id/districts/:id
  def show
    @district = @state.districts.find_by_district_number(params[:id])
    if @district.rep.nil?
      # The district is not represented. It was most likely a victim of a recent census.
      render_404 and return
    end

    @representative = Person.find_current_representative_by_state_and_district(@state.abbreviation, @district.district_number)

    @senators = Person.find_current_senators_by_state(@state.abbreviation)

    @page_title = "#{@state.name.titleize.possessive} #{@district.ordinalized_number} Congressional District"
    @users = @district.users
    @tracking_suggestions = @district.tracking_suggestions
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @district }
    end
  end

  def get_state
    @state = State.find_by_abbreviation(params[:state_id])
  end

end
