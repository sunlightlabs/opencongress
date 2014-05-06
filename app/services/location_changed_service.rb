class LocationChangedService

  JOIN_STATUS = 'MEMBER'

  def initialize(user)
    # Resets state and district based on lat/lng if present
    # if missing, tries to get from zip. If multiple results returned,
    # user stays in 'give us your address' purgatory.
    # TODO: Allow user to send feedback if they get stuck here.

    @user = user
    @districts = get_districts
    # Multiple states can be returned per zcta. See: 53511
    @states = @districts.collect(&:state).uniq
    if @states.length == 1
      @user.state = @states.first
      @user.possible_states = []
    else
      @user.state = nil
      @user.possible_states = @states
    end
    if @districts.length == 1
      @user.district = @districts.first.district
      @user.district_needs_update = false
      @user.possible_districts = []
    else
      @user.district = nil
      @user.possible_districts = @districts.collect {|d| "#{d.state}-#{d.district}"}
    end

    @user.save
    join_default_groups
    @user.district_tag
  end

  protected

  def get_districts
    if @user.user_profile.mailing_address =~ /\A[\d]{5}\Z/
      dsts = Congress.districts_locate(@user.user_profile.zipcode)
    else
      lat, lng = MultiGeocoder.coordinates(@user.user_profile.mailing_address)
      dsts = Congress.districts_locate(lat, lng).results rescue []
    end
    dsts
  end

  def join_default_groups
    if @user.state.present?
      state_group = State.find_by_abbreviation(@user.state).group rescue nil
      unless state_group.nil? or state_group.users.include?(@user)
        state_group.group_members.create(:user_id => @user.id, :status => JOIN_STATUS)
      end
    end

    if @user.district.present?
      district_group = District.find_by_district_tag(@user.district_tag).group rescue nil
      unless district_group.nil? or district_group.users.include?(@user)
        district_group.group_members.create(:user_id => @user.id, :status => JOIN_STATUS)
      end
    end
  end
end