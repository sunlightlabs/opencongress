# == Schema Information
#
# Table name: states
#
#  id           :integer          not null, primary key
#  name         :string(255)
#  abbreviation :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#

class State < ActiveRecord::Base
  ABBREVIATIONS = {
    "Alabama" => "AL",
    "Alaska" => "AK",
    "Arizona" => "AZ",
    "Arkansas" => "AR",
    "California" => "CA",
    "Colorado" => "CO",
    "Connecticut" => "CT",
    "Delaware" => "DE",
    "District of Columbia" => "DC",
    "Florida" => "FL",
    "Georgia" => "GA",
    "Hawaii" => "HI",
    "Idaho" => "ID",
    "Illinois" => "IL",
    "Indiana" => "IN",
    "Iowa" => "IA",
    "Kansas" => "KS",
    "Kentucky" => "KY",
    "Louisiana" => "LA",
    "Maine" => "ME",
    "Maryland" => "MD",
    "Massachusetts" => "MA",
    "Michigan" => "MI",
    "Minnesota" => "MN",
    "Mississippi" => "MS",
    "Missouri" => "MO",
    "Montana" => "MT",
    "Nebraska" => "NE",
    "Nevada" => "NV",
    "New Hampshire" => "NH",
    "New Jersey" => "NJ",
    "New Mexico" => "NM",
    "New York" => "NY",
    "North Carolina" => "NC",
    "North Dakota" => "ND",
    "Ohio" => "OH",
    "Oklahoma" => "OK",
    "Oregon" => "OR",
    "Pennsylvania" => "PA",
    "Rhode Island" => "RI",
    "South Carolina" => "SC",
    "South Dakota" => "SD",
    "Tennessee" => "TN",
    "Texas" => "TX",
    "Utah" => "UT",
    "Vermont" => "VT",
    "Virginia" => "VA",
    "Washington" => "WA",
    "West Virginia" => "WV",
    "Wisconsin" => "WI",
    "Wyoming" => "WY"
  }

  ABBREVIATIONS_REVERSE = ABBREVIATIONS.invert()

  has_many :districts

  has_many :v_current_roles
  has_many :roles, :through => :v_current_roles
  has_many :people, :through => :v_current_roles do
    def representatives
      where("v_current_roles.role_type = 'rep'")
    end
    def republican_representatives
      representatives.where("people.party = 'Republican'")
    end
    def democrat_representatives
      representatives.where("people.party = 'Democrat'")
    end
    def other_representatives
      representatives.where("people.party != 'Democrat' and people.party != 'Republican'")
    end
    def senators
      where("v_current_roles.role_type = 'sen'")
    end
  end

  # Pull association methods up to the instance level, for backwards compatibility
  [:representatives, :republican_representatives, :democrat_representatives, :other_representatives, :senators].each do |method|
    define_method(method) do
      people.send(method)
    end
  end

  has_one :group
  after_create :create_default_group

  def default_group_description
    "This is an automatically generated OpenCongress Group for users in #{name}. This group allows you to connect with others on the site from your state."
  end

  def create_default_group
    if group.nil?
      owner = User.find_by_login(Settings.default_group_owner_login)
      return if owner.nil?

      grp = Group.new(:user_id => owner.id,
                      :name => "OpenCongress #{name} Group",
                      :description => default_group_description,
                      :join_type => "INVITE_ONLY",
                      :invite_type => "MODERATOR",
                      :post_type => "ANYONE",
                      :publicly_visible => true,
                      :state_id => self.id
                     )
      grp.save!
    end
  end

  def to_param
    abbreviation
  end

  def user_count
    User.for_state(abbreviation).count
    # User.count_by_sql(['select count(distinct users.id) from users where state like ?;', "%#{abbreviation}%"])
    # User.count_by_solr("my_state:\"#{abbreviation}\"")
  end


  def users
    User.for_state(abbreviation)
    # User.find_by_sql(['select distinct users.id, users.login from users where state like ?;', "%#{abbreviation}%"])
    # User.find_by_solr("my_state:\"#{abbreviation}\"", :facets => {:fields => [:public_actions, :public_tracking, :my_bills_supported, :my_bills_opposed,
    #                        :my_committees_tracked, :my_bills_tracked, :my_people_tracked, :my_issues_tracked,
    #                        :my_approved_reps, :my_approved_sens, :my_disapproved_reps, :my_disapproved_sens], :limit => 10, :sort => true},
    #                        #:browse => ["public_tracking:true", "public_actions:true"]}
    #                         :order => "last_login desc")
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

  def freebase_url_name
    name.downcase.gsub(' ', '_')
  end

  def freebase_link
    "http://www.freebase.com/view/en/#{freebase_url_name}"
  end

  def freebase_description
    begin
      freebase_data['property']['/common/topic/description']['values'].first['value']
    rescue
      nil
    end
  end

  def freebase_data
    Rails.cache.fetch("state_freebase_#{id}") do
      url = "https://usercontent.googleapis.com/freebase/v1/topic/en/#{freebase_url_name}?filter=/location/us_state&filter=/common/topic/description"
      puts "Feching #{url}"
      response = HTTParty.get(url)
      if response.code == 200
        response.parsed_response
      else
        nil
      end
    end
  end

  def image_path
    "public/images/states/#{self.image_name}"
  end

  def census_url
    "http://ftp2.census.gov/geo/maps/cong_dist/cd109_gen/st_based/#{self.image_name}"
  end

  def image_name
    "cd109_#{abbreviation}.gif"
  end

  def self.make_download_script
    State.all.each do |s|
      puts "wget -q '#{s.census_url}'"
    end
  end

  def available_in_og?
    ['CA','LA','MD','WI','MN','TX'].include?(abbreviation)
  end

  def og_link
    'http://' + abbreviation.downcase + '.opengovernment.org'
  end

  def m_thumb_path
    "/images/states/thumbs_250/#{self.image_name}"
  end

  def s_thumb_path
    "/images/states/thumbs_250/#{self.image_name}"
  end

  def party_makeup_graph_url
    size = "330x130"
    colors = "CCCCFF,FFCCCC"
    title = "#{abbreviation.possessive}%20House%20Party%20Make-up"
    if other_representatives.count == 0
      if republican_representatives.count == 0
        "http://chart.apis.google.com/chart?cht=p&chd=t:#{democrat_representatives.count}&\
chs=#{size}&chl=Democrats (#{democrat_representatives.count})&chds=0,100&chco#{colors}&chtt=#{title}"
      elsif democrat_representatives.count == 0
        "http://chart.apis.google.com/chart?cht=p&chd=t:#{republican_representatives.count}&\
chs=#{size}&chl=Republicans (#{republican_representatives.count})&chds=0,100&chco=#{colors}&chtt=#{title}"
      else
        "http://chart.apis.google.com/chart?cht=p&chd=t:#{democrat_representatives.count},#{republican_representatives.count}&\
chs=#{size}&chl=Democrats (#{democrat_representatives.count})|Republicans (#{republican_representatives.count})&chds=0,100,0,100&chco=#{colors}&chtt=#{title}"

      end

    else
      "http://chart.apis.google.com/chart?cht=p&chd=t:#{democrat_representatives.count},#{republican_representatives.count},#{other_representatives.count}&\
chs=#{size}&chl=Democrats (#{democrat_representatives.count})|Republicans (#{republican_representatives.count})|Other (#{other_representatives.count})&chds=0,100,0,100,0,100&chco=#{colors}&chtt=#{title}"
    end
  end

  STATE_FOR_ABBREV = {
    "AL" => "Alabama",
    "AK" => "Alaska",
    "AS" => "American Samoa",
    "AZ" => "Arizona",
    "AR" => "Arkansas",
    "CA" => "California",
    "CO" => "Colorado",
    "CT" => "Connecticut",
    "DE" => "Delaware",
    "DC" => "District of Columbia",
    "FL" => "Florida",
    "GA" => "Georgia",
    "GU" => "Guam",
    "HI" => "Hawaii",
    "ID" => "Idaho",
    "IL" => "Illinois",
    "IN" => "Indiana",
    "IA" => "Iowa",
    "KS" => "Kansas",
    "KY" => "Kentucky",
    "LA" => "Louisiana",
    "ME" => "Maine",
    "MD" => "Maryland",
    "MA" => "Massachusetts",
    "MI" => "Michigan",
    "MN" => "Minnesota",
    "MS" => "Mississippi",
    "MO" => "Missouri",
    "MT" => "Montana",
    "NE" => "Nebraska",
    "NV" => "Nevada",
    "NH" => "New Hampshire",
    "NJ" => "New Jersey",
    "NM" => "New Mexico",
    "NY" => "New York",
    "NC" => "North Carolina",
    "ND" => "North Dakota",
    "OH" => "Ohio",
    "OK" => "Oklahoma",
    "OR" => "Oregon",
    "PA" => "Pennsylvania",
    "PR" => "Puerto Rico",
    "RI" => "Rhode Island",
    "SC" => "South Carolina",
    "SD" => "South Dakota",
    "TN" => "Tennessee",
    "TX" => "Texas",
    "UT" => "Utah",
    "VI" => "Virgin Islands",
    "VT" => "Vermont",
    "VA" => "Virginia",
    "WA" => "Washington",
    "WV" => "West Virginia",
    "WI" => "Wisconsin",
    "WY" => "Wyoming" }

    # Make a reverse map for state names to abbrevs, with downcase'd state names.
    ABBREV_FOR_STATE = STATE_FOR_ABBREV.merge(STATE_FOR_ABBREV) { |k,ov| ov.downcase }.invert

    # This is great for select lists
    PAIRS_SORTED = STATE_FOR_ABBREV.invert.to_a.sort

    def self.abbrev_for(name)
      ABBREV_FOR_STATE[name.downcase]
    end

    def self.for_abbrev(abbr)
      return nil if abbr.blank?
      STATE_FOR_ABBREV[abbr.upcase]
    end

    RESIDENT_FOR_ABBREV = {
    "AL" => "Alabamian",
    "AK" => "Alaskan",
    "AR" => "Arkansan",
    "AZ" => "Arizonan",
    "AS" => "American Samoan",
    "CA" => "Californian",
    "CO" => "Coloradan",
    "CT" => "Connecticuter",
    "DE" => "Delawarean",
    "FL" => "Floridian",
    "GA" => "Georgian",
    "GU" => "Guamanian",
    "HI" => "Hawaiian",
    "ID" => "Idahoan",
    "IL" => "Illinoisan",
    "IN" => "Indianian",
    "IA" => "Iowan",
    "KS" => "Kansan",
    "KY" => "Kentuckian",
    "LA" => "Louisianian",
    "ME" => "Mainer",
    "MD" => "Marylander",
    "MA" => "Massachusettsan",
    "MI" => "Michiganian",
    "MN" => "Minnesotan",
    "MS" => "Mississippian",
    "MO" => "Missourian",
    "MT" => "Montanan",
    "NE" => "Nebraskan",
    "NV" => "Nevadan",
    "NH" => "New Hampshirite",
    "NJ" => "New Jerseyan",
    "NM" => "New Mexican",
    "NY" => "New Yorker",
    "NC" => "North Carolinian",
    "ND" => "North Dakotan",
    "OH" => "Ohioan",
    "OK" => "Oklahoman",
    "OR" => "Oregonian",
    "PA" => "Pennsylvanian",
    "PR" => "Puerto Rican",
    "RI" => "Rhode Islander",
    "SC" => "South Carolinian",
    "SD" => "South Dakotan",
    "TN" => "Tennessean",
    "TX" => "Texan",
    "UT" => "Utahn",
    "VT" => "Vermonter",
    "VA" => "Virginian",
    "WA" => "Washingtonian",
    "WV" => "West Virginian",
    "WI" => "Wisconsinite",
    "WY" => "Wyomingite" }

  def self.resident_for_abbrev(abbr)
    RESIDENT_FOR_ABBREV[abbr.upcase]
  end


end
