# encoding=utf-8
class District < ActiveRecord::Base
  # district_number 0 is reserved for at-large districts

  belongs_to :state
  has_many :watch_dogs
  has_one :current_watch_dog, :class_name => "WatchDog", :conditions => ["is_active = ?", true], :order => "created_at desc"
  has_one :group
  after_create :create_default_group

  def default_group_description
    "This is an automatically generated OpenCongress Group for users in #{possessive_state_district_text}. This group allows you to connect with others on the site from your district."
  end

  def create_default_group
    if group.nil?
      owner = User.find_by_login(Settings.default_group_owner_login)
      return if owner.nil?

      grp = Group.new(:user_id => owner.id,
                      :name => "OpenCongress #{district_state_text} Group",
                      :description => default_group_description,
                      :join_type => "INVITE_ONLY",
                      :invite_type => "MODERATOR",
                      :post_type => "ANYONE",
                      :publicly_visible => true,
                      :district_id => self.id
                     )
      grp.save!
    end
  end

  def user_count
    User.for_district(state.abbreviation, district_number).count
    # User.count_by_sql(['select count(distinct users.id) from users where district like ?;', "%#{state.abbreviation}-#{district_number}%"])
    # User.count_by_solr("my_state:\"#{abbreviation}\"")
  end


  def users
    User.for_district(state.abbreviation, district_number)
    # User.find_by_sql(['select distinct users.id, users.login from users where district like ?;', "%#{state.abbreviation}-#{district_number}%"])
    # User.find_by_solr("my_district:#{self.state.abbreviation}-#{district_number}", :facets => {:fields => [:public_actions, :public_tracking, :my_bills_supported, :my_bills_opposed,
    #                        :my_committees_tracked, :my_bills_tracked, :my_people_tracked, :my_issues_tracked,
    #                        :my_approved_reps, :my_approved_sens, :my_disapproved_reps, :my_disapproved_sens], :limit => 10, :sort => true, :browse => ["public_tracking:true", "public_actions:true"]}, :order => "last_login desc")
  end

  def all_users
    users
    # User.find_by_sql(['select distinct users.id, users.login from users where district like ?;', "%#{state.abbreviation}-#{district_number}%"])
    # User.find_by_solr("my_district:#{self.state.abbreviation}-#{district_number}", :facets => {:fields => [:public_actions, :public_tracking, :my_bills_supported, :my_bills_opposed,
    #                        :my_committees_tracked, :my_bills_tracked, :my_people_tracked, :my_issues_tracked,
    #                        :my_approved_reps, :my_approved_sens, :my_disapproved_reps, :my_disapproved_sens], :limit => 500, :sort => true}, :order => "last_login desc")

  end

  def all_active_users
    User.active.for_district(state.abbreviation, district_number)
    # User.find_by_sql(['select distinct users.id, users.login from users where district like ? AND previous_login_date >= ;',
    #                   "%#{state.abbreviation}-#{district_number}%", 2.months.ago])
    # query = "my_district:#{self.state.abbreviation}-#{district_number} AND last_login:[#{(Time.now - 2.months).iso8601[0,19] + 'Z'} TO *] AND total_number_of_actions:[5 TO *]"
    # User.find_by_solr(query, :limit => 500, :order => "last_login desc")

  end

  # TODO: This finder returned incongrous results with its companion method, all_active_users.
  #       Updating it to use the same scopes, but keep an eye on whatever the implications may be.
  def all_active_users_count
    User.active.for_district(state.abbreviation, district_number).count
    # query = "my_district:#{self.state.abbreviation}-#{district_number} AND last_login:[#{(Time.now - 2.months).iso8601[0,19] + 'Z'} TO *] AND total_number_of_actions:[5 TO *]"
    # User.count_by_solr(query)

  end

  def self.csv_of_active_users

    require 'csv'
    outfile = File.open('public/active_users_per_district_detailed.csv', 'wb')
    CSV::Writer.generate(outfile) do |csv|
        csv << ['STATE', 'DISTRICT', 'LOGIN', 'LAST LOGIN','TOTAL ACTIONS']
        District.find(:all, :order => ["state_id, district_number asc"]).each do |d|
           d.all_active_users.results.each do |u|
             csv << [d.state.abbreviation,
                     d.district_number,
                     u.login,
                     u.last_login.to_date.to_s,
                     u.action_count
                    ]
           end
        end
    end
    outfile.close

  end

  def tag
    "#{state.abbreviation}-#{district_number}"
  end

  def self.find_by_district_tag(tag)  # ie, CA-33
    abbr, number = tag.split(/-/)
    state = State.find_by_abbreviation(abbr)
    if state
      return self.find_by_state_id_and_district_number(state.id, number.to_i)
    end

    return nil
  end

  def self.csv_of_active_users_count

    require 'csv'
    outfile = File.open('public/active_users_per_district.csv', 'wb')
    CSV::Writer.generate(outfile) do |csv|
        csv << ['STATE', 'DISTRICT', 'TOTAL USERS', 'ACTIVE USERS']

        District.find(:all, :order => ["state_id, district_number asc"]).each do |d|
           csv << [d.state.abbreviation,d.district_number,d.user_count,d.all_active_users_count]
        end
    end
    outfile.close

  end

  def tracking_suggestions
    # temporarily removing solr for now - June 2012
    return [0, {}]

    facets = self.users.facets
    my_trackers = 0
    facet_results_hsh = {:my_bills_supported_facet => [],
                         :my_people_tracked_facet => [],
                         :my_issues_tracked_facet => [],
                         :my_bills_tracked_facet => [],
                         :my_approved_reps_facet => [],
                         :my_approved_sens_facet => [],
                         :my_disapproved_reps_facet => [],
                         :my_disapproved_sens_facet => [],
                         :public_actions_facet => [],
                         :public_tracking_facet => [],
                         :my_committees_tracked_facet => [],
                         :my_bills_opposed_facet => []}
    facet_results_ff = facets['facet_fields']
    if facet_results_ff && facet_results_ff != []

      facet_results_ff.each do |fkey, fvalue|
        facet_results = facet_results_ff[fkey]

        #solr running through acts as returns as a Hash, or an array if running through tomcat...hence this stuffs
        facet_results_temp_hash = Hash[*facet_results] unless facet_results.class.to_s == "Hash"
        facet_results_temp_hash = facet_results if facet_results.class.to_s == "Hash"
        logger.info facet_results_temp_hash.to_yaml

        facet_results_temp_hash.each do |key,value|
#          if key == self.ident.to_s && fkey == "my_bills_tracked_facet"
#            my_trackers = value
#          else
            logger.info "#{fkey} - #{key} - #{value}"
            unless facet_results_hsh[fkey.to_sym].length == 5
              object = Person.find_by_id(key) if fkey == "my_people_tracked_facet" || fkey =~ /my_approved_/ || fkey =~ /my_disapproved_/
              object = Subject.find_by_id(key) if fkey == "my_issues_tracked_facet"
              object = Bill.find_by_ident(key) if fkey == "my_bills_tracked_facet"
              object = Bill.find_by_id(key) if fkey =~ /my_bills_supported/ || fkey =~ /my_bills_opposed/
              facet_results_hsh[fkey.to_sym] << {:object => object, :trackers => value}
            end
#          end
        end
      end
    else
      return [my_trackers,{}]
    end
    unless facet_results_hsh.empty?
      #sort the hashes
      facet_results_hsh[:my_people_tracked_facet].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      facet_results_hsh[:my_issues_tracked_facet].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      facet_results_hsh[:my_bills_tracked_facet].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      facet_results_hsh[:my_approved_sens_facet].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      facet_results_hsh[:my_bills_opposed_facet].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      facet_results_hsh[:my_bills_supported_facet].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      return [my_trackers, facet_results_hsh]
    else
      return [my_trackers,{}]
    end
  end

  def ordinalized_number
    if self.district_number == 0
      "At Large"
    else
      district_number.ordinalize
    end
  end

  def district_state_text
    self.state.abbreviation + "-" + self.district_number.to_s
  end

  def possessive_state_district_text
    "#{state.name.possessive} #{ordinalized_number} district"
  end

  def freebase_url_name
    if district_number == 0
      "#{state.name.possessive} at large congressional district".gsub(' ', '_').sub('’', '').downcase # Strip out the unicode apostrophe
    else
      "#{state.name.possessive} #{district_number.ordinalize} congressional district".gsub(' ', '_').sub('’', '').downcase # Strip out the unicode apostrophe
    end
  end

  def freebase_data
    Rails.cache.fetch("district_freebase_#{id}") do
      url = "https://usercontent.googleapis.com/freebase/v1/topic/en/#{freebase_url_name}?filter=/common/topic/description"
      puts "Feching #{url}"
      response = HTTParty.get(url)
      if response.code == 200
        response.parsed_response
      else
        nil
      end
    end
  end

  def freebase_description
    begin
      freebase_data['property']['/common/topic/description']['values'].first['value']
    rescue
      nil
    end
  end

  def freebase_link
    "http://www.freebase.com/view/en/#{freebase_url_name}"
  end

  def wiki_link
    "/wiki/#{state.abbreviation}-#{district_number == 0 ? "AL" : district_number}"
  end

  def rep
    Person.rep.find_by_state_and_district(self.state.abbreviation, district_number.to_s)
  end

  def sens
    Person.sen.where(:state => state.abbreviation)
  end

  ##
  # Geocodes an address and returns the District model corresponding
  # to the resulting (lat,lng). The geocoder will attempt to geocode
  # anything. To avoid discrepencies between the geocoder address
  # parsing and local address parsing, we use the geocoder results
  # to determine whether a sufficiently specific address was submitted.
  #
  # E.g. for 42223, which includes both Fort Campbell KY and Clarksville TN,
  # the function would return both KY-1 and TN-7 while for Fort Campbell, KY
  # it would return just KY-1.

  def self.from_address (address)

    # Mapquest will return a less specific result for 'Clarksville, TN 42223'
    # than it will for 'Clarksville, TN'. If zipcode regex matches, we try
    # to geocode all three forms (full combination, without zipcode, and just
    # zip code) and use the most specific result.
    m = /((.+)\s+(\d{5}(?:-\d{2}(?:\d{2})?)?)?)\Z/.match(address)
    if m.nil?
      geo = Geocoder.search(address)[0]
    else
      mapquest_granularity_ranking = [
        'P1', 'L1', 'I1', 'B1', 'B2', 'B3', 'Z4', 'Z3', 'Z2', 'A5', 'Z1', 'A4', 'A3', 'A1'
      ]
      geos = m.captures.map do |c|
        # Geocodes each capture result: Full address, Without Zip, Zip only
        Geocoder.search(c)[0]
      end.filter do |g|
        # Filters results to only those where the state matches the original query
        address.include?(g.data['adminArea3'])
      end.compact.sort_by do |g|
        # Sorts by Mapquest Specificity Code
        granularity_code = g.data['geocodeQualityCode'].slice(0, 2)
        mapquest_granularity_ranking.index(granularity_code) or mapquest_granularity_ranking.length
      end
      geo = geos.first
    end

    return [] if geo.nil?
    return [] if ['COUNTRY', 'STATE'].include?(geo.data['geocodeQuality'])
    if geo.data['geocodeQuality'] == 'ZIP' # This means just Zip5
      dsts = Congress.districts_locate(geo.data['postalCode']).results
    else
      lat = geo.data['latLng']['lat']
      lng = geo.data['latLng']['lng']
      dsts = Congress.districts_locate(lat, lng).results
    end

    if dsts.length == 1
      includes(:state).where(:district_number => dsts.first.district,
                             :states => { :abbreviation => dsts.first.state })
    else
      # Partial filtering in database
      states_abbrevs = dsts.map(&:state)
      dst_numbers = dsts.map(&:district)
      districts = includes(:state).where(:district_number => dst_numbers,
                                         :states => { :abbreviation => states_abbrevs })

      # Final, accurate filtering
      dst_hashes = dsts.map{ |dst| dst.to_hash }
      districts.select{ |d| dst_hashes.include?({'state' => d.state.abbreviation, 'district' => d.district_number}) }
    end
  end
end
