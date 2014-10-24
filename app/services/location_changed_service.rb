require 'multi_geocoder'

class LocationChangedService

  JOIN_STATUS = 'MEMBER'

  ##
  # Resets state, district, and representative_id based on whatever address
  # data is available for the user. If multi results returned, user stays in
  # 'give us your address' purgatory.
  # TODO: Allow user to send feedback if they get stuck here.
  #
  # @user {User} The user to update district, state, and representative for
  #
  def initialize(user)

    # skip the change_location callback in this block so we don't enter infinite loop
    UserProfile.skip_callback(:save, :after, :change_location!)

    @user = user
    @user.district = nil
    @user.district_needs_update = true

    # Get possible district and state for this user
    @districts = get_districts()

    # Multiple states can be returned per zcta. "EXAMPLE: 53511"
    @states = @districts.collect(&:state).uniq

    # Handles updating state and district data for user
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

    # Handles setting representative id and saving user.
    if @user.state && @user.district
      rep = Person.find_current_representative_by_state_and_district(@user.state, @user.district)
      @user.representative = rep ? rep : nil
      # TODO log failure of Person lookup by state and district?
    else
      @user.representative = nil
    end

    # save and
    @user.save()
    join_default_groups()
    UserProfile.set_callback(:save, :after, :change_location!)
    return @user.district_tag()
  end

  protected

  ##
  # Gets a user's possible district(s) by performing an exhaustive lookup of address information
  # starting from zipcode and moving to full address.
  #
  # @return {Hash} contains attributes "results" and "count". The "results" attribute maps
  #                to a List of Hashes that contain attributes "state" and "district".
  #
  def get_districts
    dsts = []
    if @user.zipcode  # try to locate districts from zipcode
      dsts = Congress.districts_locate(@user.zipcode).results rescue [] # external API call
    end
    if dsts and dsts.length != 1 and @user.street_address
      lat, lng = MultiGeocoder.coordinates(@user.mailing_address_as_hash())
      dsts = Congress.districts_locate(lat, lng).results rescue [] # external API call magic
    end
    return dsts
  end

  ##
  # Join user in default groups for their district and state
  #
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