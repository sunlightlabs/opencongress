''# == Schema Information
#
# Table name: committees
#
#  id                :integer          not null, primary key
#  name              :string(255)
#  subcommittee_name :string(255)
#  fti_names         :tsvector
#  active            :boolean          default(TRUE)
#  code              :string(255)
#  page_views_count  :integer
#  thomas_id         :string(255)
#  chamber           :string(255)
#  parent_id         :integer
#  homepage_url      :string(255)
#

require_dependency 'viewable_object'

class Committee < Bookmarkable

  #========== INCLUDES

  include ViewableObject
  include SearchableObject

  #========== CONFIGURATIONS

  # elasticsearch configuration
  settings ELASTICSEARCH_SETTINGS do
    mappings ELASTICSEARCH_MAPPINGS do
      [:name, :subcommittee_name].each do |index|
        indexes index, ELASTICSEARCH_INDEX_OPTIONS
      end
    end
  end

  #========== CONSTANTS

  DISPLAY_OBJECT_NAME = 'Committee'

  #I think this is unfortunately the best way to do this.
  # TODO: deprecate me and populate homepage_url
  HOMEPAGES = {
      "house administration" => "http://www.house.gov/cha/",
      "house agriculture" => "http://agriculture.house.gov/",
      "house appropriations" => "http://www.house.gov/appropriations/",
      "house armed services" => "http://www.house.gov/hasc/",
      "house budget" => "http://www.house.gov/budget/",
      "house education and the workforce" => "http://edworkforce.house.gov",
      "house energy and commerce" => "http://www.house.gov/commerce/",
      "house financial services" => "http://www.house.gov/financialservices/",
      "house government reform" => "http://www.house.gov/reform/",
      "house homeland security" => "http://hsc.house.gov/",
      "house international relations" => "http://www.house.gov/international_relations/",
      "house judiciary" => "http://www.house.gov/judiciary/",
      "house resources" => "http://resourcescommittee.house.gov",
      "house rules" => "http://www.house.gov/rules/",
      "house science" => "http://www.house.gov/science/",
      "house small business" => "http://www.house.gov/smbiz/",
      "house standards of official conduct" => "http://www.house.gov/ethics/",
      "house transportation and infrastructure" => "http://www.house.gov/transportation/",
      "house veterans' affairs" => "http://veterans.house.gov",
      "house ways and means " => "http://waysandmeans.house.gov",
      "house intelligence (permanent select)" => "http://intelligence.house.gov",
      "house select bipartisan committee to investigate the preparation for and response to hurricane katrina" => "http://katrina.house.gov",
      "senate agriculture, nutrition, and forestry" => "http://agriculture.senate.gov/",
      "senate appropriations" => "http://appropriations.senate.gov/","senate armed services" => "http://armed-services.senate.gov/",
      "senate banking, housing, and urban affairs" => "http://banking.senate.gov/",
      "senate budget" => "http://budget.senate.gov/",
      "senate commerce, science, and transportation" => "http://commerce.senate.gov/",
      "senate energy and natural resources" => "http://energy.senate.gov/",
      "senate environment and public works" => "http://epw.senate.gov/",
      "senate finance" => "http://finance.senate.gov/",
      "senate foreign relations" => "http://foreign.senate.gov/",
      "senate health, education, labor, and pensions" => "http://help.senate.gov/",
      "senate homeland security and governmental affairs" => "http://hsgac.senate.gov/",
      "senate judiciary" => "http://judiciary.senate.gov/",
      "senate rules and administration" => "http://rules.senate.gov/",
      "senate small business and entrepreneurship" => "http://sbc.senate.gov/",
      "senate veterans' affairs" => "http://veterans.senate.gov/",
      "senate indian affairs" => "http://indian.senate.gov/",
      "senate select committee on ethics" => "http://ethics.senate.gov/",
      "senate select committee on intelligence" => "http://intelligence.senate.gov/",
      "senate aging (special)" => "http://aging.senate.gov",
      "senate joint committee on printing" => "http://jcp.senate.gov/",
      "senate joint committee on taxation" => "http://www.house.gov/jct",
      "senate joint economic committee" => "http://jec.senate.gov/"
  }

  STOP_WORDS = %w(committee subcommittee)

  # Different formats to serialize as JSON
  SERIALIZATION_STYLES = {
    simple: {},
    elasticsearch: {
      methods: [:short_name, :bookmark_count, :bills_sponsored_count],
      include: [:reports, :names]
    }
  }

  #========== VALIDATORS

  validates_uniqueness_of :thomas_id

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :parent, :class_name => 'Committee'

  #----- HAS_ONE

  has_one :committee_stats
  has_one :wiki_link, :as => 'wikiable'

  #----- HAS_MANY
  
  has_many :committee_people
  has_many :people, :through => :committee_people

  has_many :bill_committees
  has_many :bills, -> { order('bills.lastaction DESC') },
           :through => :bill_committees

  has_many :meetings, :class_name => 'CommitteeMeeting'

  has_many :committee_reports
  has_many :reports, :class_name => 'CommitteeReport'

  has_many :comments, :as => :commentable

  has_many :names, :class_name => 'CommitteeName'

  has_many :subcommittees, :class_name => 'Committee', :foreign_key => 'parent_id'

  has_many :congress_chambers, :through => :congress_chamber_committees

  #========== ALIASES

  alias :members :people # for convenience, seems to make more sense

  #========== METHODS

  #----- CLASS

  def self.search_query(query)
    {
      indices: {
        index: 'committees',
        query: {
          function_score: {
            query: {
              dis_max: {
                queries: [
                  {
                    fuzzy_like_this_field: {
                      name: {
                        like_text: query,
                        boost: ELASTICSEARCH_BOOSTS[:extreme],
                        analyzer: 'english'
                      }
                    },
                  }
                ]
              }
            },
            functions: [
              {
                field_value_factor: {
                  field: 'bills_sponsored_count',
                  modifier: 'sqrt',
                  factor: 1
                }
              }
            ],
            score_mode: 'avg'
          }
        },
        no_match_query: 'none'
      }
    }
  end

  def self.find_by_query(committee, subcommittee)
    terms = committee.split.concat(subcommittee.split).uniq.map { |c| c.match(/\W*(\w+)\W*/).captures[0].downcase }
    sub_terms = subcommittee.split.uniq.map { |c| c.match(/\W*(\w+)\W*/).captures[0].downcase }
    query = terms.reject { |t| STOP_WORDS.include? t }.join " & "
    if sub_terms.empty?
      cs = Committee.find_by_sql("SELECT * FROM committees WHERE fti_names @@ to_tsquery('english', '#{query}') AND subcommittee_name is null;")
    else
      cs = Committee.find_by_sql("SELECT * FROM committees WHERE fti_names @@ to_tsquery('english', '#{query}');")
    end
    cs
  end

  def self.by_chamber(chamber, opts={})
    opts = {include_joint_committees: true, include_subcommittees: false}.merge(opts)
    #CAUTION: there is careful string interpolation into SQL in following line
    parent_id_clause = opts[:include_subcommittees] ? nil : 'AND parent_id IS NULL'
    Committee.where("(chamber LIKE ? or chamber LIKE ?) AND active = 't' #{parent_id_clause}", chamber, (opts[:include_joint_committees] ? 'joint' : ''))
  end

  # the following 3 methods are likely broken and also likely not in use
  def self.find_by_people_name_ci(name)
    Committee.where('lower(people_name) = ?', name.downcase).first
  end

  def self.find_by_name_ci(name)
    Committee.find(:first, :conditions => ["lower(name) = ?", name.downcase])
  end

  def self.find_by_bill_name_ci(name)
    Committee.find(:first, :conditions => ["lower(bill_name) = ?", name.downcase])
  end

  def self.top20_viewed
    comms = ObjectAggregate.popular('Committee')

    (comms.select {|b| b.stats.entered_top_viewed.nil? }).each do |bv|
      bv.stats.entered_top_viewed = Time.now
      bv.save
    end

    (comms.sort { |c1, c2| c2.stats.entered_top_viewed <=> c1.stats.entered_top_viewed })
  end

  def self.full_text_search(q, options = {})
    Committee.find_by_sql(["SELECT *, rank(fti_names, ?, 1) as tsearch_rank FROM committees
                           WHERE fti_names @@ to_tsquery('english', ?) order by tsearch_rank DESC;", q, q])
  end

  #----- Instance

  public

  def display_object_name
    DISPLAY_OBJECT_NAME
  end
  
  def atom_id_as_feed
    "tag:opencongress.org,#{OpenCongress::Application::CONGRESS_START_DATES[Settings.default_congress]}:/committee_feed/#{id}"
  end
  
  def atom_id_as_entry
    # dates for committees are weird, so let use the beginning of each congress session
    "tag:opencongress.org,#{OpenCongress::Application::CONGRESS_START_DATES[Settings.default_congress]}:/committee/#{id}"
  end


  def chair
    membership = committee_people.where(role: %w(Chair Chairman), session: Settings.default_congress).first
    membership and membership.person
  end
 
  def vice_chair
    membership = committee_people.where(role: 'Vice Chairman', session: Settings.default_congress).first
    membership and membership.person
  end

  def ranking_member
    membership = committee_people.where(role: 'Ranking Member', session: Settings.default_congress).first
    membership and membership.person
  end

  # Returns string concatenating id and url_name to create prettier URLS
  def to_param
    "#{id}_#{url_name}"
  end

  def ident
    "Committee #{id}"
  end

  def homepage
    self.homepage_url.present? ? self.homepage_url : HOMEPAGES[name.downcase]
  end

  # Retrieves all the bills this committee sponsored
  #
  # @param limit [Integer, nil] max number of bills to return, nil for no limit
  # @return [Relation<Bill>] return sponsored bills
  def bills_sponsored(limit=nil)
    ids = Bill.joins(:bill_committees).select('bills.id').where('bills_committees.committee_id = ? AND session = ?', id, Settings.default_congress).order('lastaction DESC').limit(limit).collect {|b| b.id }
    Bill.includes(:bill_titles).where(id:ids).order('bills.lastaction DESC')
  end

  # Convenience method for obtaining the number of sponsored bills
  #
  # @param limit [Integer, nil] max number of bills to return, nil for no limit
  # @return [Integer] return count of sponsored bills
  def bills_sponsored_count(limit=nil)
    bills_sponsored(limit).count
  end
  
  def latest_major_actions(num)
    Action.find_by_sql( ["SELECT actions.* FROM actions, bills_committees, bills 
                                    WHERE bills_committees.committee_id = ? AND 
                                          (actions.action_type = 'introduced' OR
                                           actions.action_type = 'topresident' OR
                                           actions.action_type = 'signed' OR
                                           actions.action_type = 'enacted' OR
                                           actions.action_type = 'vetoed') AND
                                           actions.bill_id = bills.id AND
                                          bills_committees.bill_id = bills.id
                                    ORDER BY actions.date DESC 
                                    LIMIT #{num}", id])
  end

  def has_wiki_link?
    self.wik_url.blank? ? false : true
  end

  def wiki_url
    self.wiki_link.nil? ? '' : "#{Settings.wiki_base_url}/#{self.wiki_link.name}"
  end

  def proper_name
    if name.blank?
      pn = subcommittee_name
    else
      pn = name
      pn += " - #{subcommittee_name}" unless subcommittee_name.nil?
    end
    pn
  end

  def title_for_share
    proper_name
  end
  
  def short_name
    proper_name.sub(/house\s+|senate\s+/i, "")
  end
	
  def main_committee_name
    name.blank? ? subcommittee_name : name
  end

  def future_meetings
    self.meetings.where('meeting_at > ?', Time.now)
  end
  
  def stats
    self.committee_stats = CommitteeStats.new(:committee => self) unless self.committee_stats.present?
    self.committee_stats
  end

  def new_bills_since(current_user, congress = Settings.default_congress)
    time_since = current_user.previous_login_date
    time_since = 200.days.ago if Rails.env.development?

    bills.joins(:actions)
         .where('bills.session = ? AND actions.datetime > ? AND actions.action_type = ?', congress, time_since, 'introduced')
         .order('bills.introduced DESC')
         .limit(20)
  end

  def latest_reports(limit = 5)
    self.committee_reports.where('reported_at IS NOT NULL').order('reported_at DESC').limit(limit)
  end

  def new_reports_since(current_user, congress = Settings.default_congress)
    time_since = current_user.previous_login_date
    time_since = 200.days.ago if Rails.env.development?
    committee_reports.where('reported_at > ? ', time_since).limit(20).order('reported_at DESC')
  end

  def comments_since_last_login(current_user)
    comments.where('created_at > ?', current_user.previous_login_date).count
  end

  private

  def url_name
    proper_name.downcase.gsub(/[\s\-]+/, "_").gsub(/[,\'\(\)]/,"")
  end

end