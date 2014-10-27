# == Schema Information
#
# Table name: people
#
#  id                        :integer          not null, primary key
#  firstname                 :string(255)
#  middlename                :string(255)
#  lastname                  :string(255)
#  nickname                  :string(255)
#  birthday                  :date
#  gender                    :string(1)
#  religion                  :string(255)
#  url                       :string(255)
#  party                     :string(255)
#  osid                      :string(255)
#  bioguideid                :string(255)
#  title                     :string(255)
#  state                     :string(255)
#  district                  :string(255)
#  name                      :string(255)
#  email                     :string(255)
#  fti_names                 :public.tsvector
#  user_approval             :float            default(5.0)
#  biography                 :text
#  unaccented_name           :string(255)
#  metavid_id                :string(255)
#  youtube_id                :string(255)
#  website                   :string(255)
#  congress_office           :string(255)
#  phone                     :string(255)
#  fax                       :string(255)
#  contact_webform           :string(255)
#  watchdog_id               :string(255)
#  page_views_count          :integer
#  news_article_count        :integer          default(0)
#  blog_article_count        :integer          default(0)
#  total_session_votes       :integer
#  votes_democratic_position :integer
#  votes_republican_position :integer
#  govtrack_id               :integer
#  fec_id                    :string(255)
#  thomas_id                 :string(255)
#  cspan_id                  :integer
#  lis_id                    :string(255)
#  death_date                :date
#  twitter_id                :string(255)
#

require_dependency 'viewable_object'
require_dependency 'multi_geocoder'
require_dependency 'wiki_connection'

class Person < Bookmarkable

  #========== INCLUDES

  include ViewableObject

  #========== CLASS VARIABLES

  @@DISPLAY_OBJECT_NAME = 'Person'

  @@NONVOTING_TERRITORIES = [ 'AS', 'DC', 'GU', 'PR', 'VI' ]

  #========== CONSTANTS

  SERIALIZATION_OPS = {:methods =>
                           [:oc_user_comments, :oc_users_tracking],
                       :include => [:recent_news, :recent_blogs]}.freeze

  #========== CALLBACKS

  before_update :set_party
  before_save :set_unaccented_name

  #========== RELATIONS

  #----- HAS_ONE

  has_one :person_stats, :dependent => :destroy
  has_one :wiki_link, :as => 'wikiable'

  #----- HAS_MANY

  has_many :person_identifiers, foreign_key: :bioguideid, primary_key: :bioguideid #keep this when merging beta
  has_many :committees,
           :through => :committee_people
  has_many :committee_people, -> { where("committees_people.session = ?", Settings.default_congress ) }
  has_many :bills, -> { includes([ :bill_titles, :actions ]).where("bills.session = ?", Settings.default_congress).order('bills.introduced DESC') },
           :foreign_key => :sponsor_id
  has_many :bill_cosponsors
  has_many :bills_cosponsored, -> { where('bills.session = ?', Settings.default_congress).order('bills.introduced DESC') },
           :class_name => 'Bill', :through => :bill_cosponsors, :source => :bill
  has_many :roles, -> { order('roles.startdate DESC') }
  has_many :roll_call_votes, -> { includes(:roll_call).order('roll_calls.date DESC') }
  has_many :commentary,
           :as => :commentariable
  has_many :news, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='t'").order('commentaries.date DESC, commentaries.id DESC') },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :blogs, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='f'").order('commentaries.date DESC, commentaries.id DESC') },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :idsorted_news, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='t'").order('commentaries.id DESC') },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :idsorted_blogs, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='f'").order('commentaries.id DESC') },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :recent_news, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='t'").order('commentaries.date DESC, commentaries.id DESC').limit(10) },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :recent_blogs, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='f'").order('commentaries.date DESC, commentaries.id DESC').limit(10) },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :cycle_contributions, -> { order('people_cycle_contributions.cycle DESC') },
           :class_name => 'PersonCycleContribution'
  has_many :committee_reports
  has_many :featured_people, -> { order('created_at DESC')}
  has_many :comments, :as => :commentable
  has_many :videos, -> { order('videos.video_date DESC, videos.id') }
  has_many :person_approvals
  has_many :fundraisers, -> { order('fundraisers.start_time DESC') }

  with_options :class_name => "RollCall", :through => :roll_call_votes, :source => :roll_call do |rc|
    rc.has_many :unabstained_roll_calls, -> { joins(:bill).where("roll_call_votes.vote NOT IN ('Not Voting', '0') AND bills.session = ?", Settings.default_congress) }
    rc.has_many :abstained_roll_calls,  -> { joins(:bill).where("vote IN ('Not Voting', '0') AND bills.session = ?", Settings.default_congress) }
    rc.has_many :party_votes, ->(party=self.party){ joins(:bill).where("((roll_calls.#{party == 'Democrat' ? 'democratic_position' : 'republican_position'} = 't' AND vote IN ('Yea', 'Aye', '+')) OR (roll_calls.#{party == 'Democrat' ? 'democratic_position' : 'republican_position'} = 'f' AND vote IN ('No', 'Nay', '-'))) AND bills.session = #{Settings.default_congress}") }
  end

  acts_as_formageddon_recipient # contains has_many relationships

  #========== SCOPES

  scope :republican, -> { where(party: "Republican") }
  scope :democrat, -> { where(party: "Democrat") }
  scope :independent, -> { where("party != 'Republican' AND party != 'Democrat'") }
  scope :in_state, ->(state) { where(state: state.upcase) }

  scope :sen, -> { includes(:roles).where(["roles.role_type='sen' AND roles.enddate > ?", Date.today]).references(:roles) }
  scope :rep, -> { includes(:roles).where(["roles.role_type='rep' AND roles.enddate > ?", Date.today]).references(:roles) }
  scope :legislator, -> { includes(:roles).where(["(roles.role_type='sen' OR roles.role_type='rep') AND roles.enddate > ?", Date.today]) }
  
  scope :on_date, ->(date) {
    includes(:roles).where(
      ['roles.startdate <= ? and roles.enddate >= ?', 
      date.to_s, date.to_s]
    ).references(:roles)
  }

  #========== ALIASES

  alias :blog :blogs

  #========== METHODS

  #----- CLASS

  def self.custom_index_rebuild
    ['rep','sen'].each{|title|
      Person.rebuild_solr_index(30) do |person, options|
        person.find(:all, options.merge({:joins => :roles, :select => "people.*", :conditions => ["roles.person_id = people.id AND roles.role_type='#{title}' AND roles.enddate > ?", Date.today]}))
      end
    }
  end

  def self.random_commentary(person_id, type, limit = 1, since = Settings.default_count_time)
    p = Person.find(person_id)
    random_item = nil
    if p then random_item = type == 'news' ? p.idsorted_news.find(:first) : p.idsorted_blogs.find(:first) end
    return random_item ? [p,random_item] : [nil,nil]
  end

  def self.list_chamber(chamber, congress, order, limit = nil)
    def_count_days = Settings.default_count_time.to_i / 24 / 60 / 60
    lim = limit.nil? ? '' : "LIMIT #{limit}"

    Person.find_by_sql(["SELECT people.*,
       COALESCE(person_approvals.person_approval_avg, 0) as person_approval_average,
       COALESCE(bills_sponsored.sponsored_bills_count, 0) as sponsored_bills_count,
       COALESCE(people.total_session_votes, 0) as total_roll_call_votes,
       CASE WHEN people.party = 'Democrat' THEN COALESCE(people.votes_democratic_position, 0)
            WHEN people.party = 'Republican' THEN COALESCE(people.votes_republican_position, 0)
            ELSE 0
       END as party_roll_call_votes,
       COALESCE(aggregates.view_count, 0) as view_count,
       COALESCE(aggregates.blog_count, 0) as blog_count,
       COALESCE(aggregates.news_count, 0) as news_count
    FROM people
    LEFT OUTER JOIN roles on roles.person_id=people.id
    LEFT OUTER JOIN (select person_approvals.person_id as person_approval_id,
                     count(person_approvals.id) as person_approval_count,
                     avg(person_approvals.rating) as person_approval_avg
                    FROM person_approvals
                    GROUP BY person_approval_id) person_approvals
      ON person_approval_id = people.id

    LEFT OUTER JOIN (select sponsor_id, count(id) as sponsored_bills_count
                    FROM bills
                    WHERE bills.session = #{congress}
                    GROUP BY sponsor_id) bills_sponsored
      ON bills_sponsored.sponsor_id = people.id
     LEFT OUTER JOIN (SELECT object_aggregates.aggregatable_id,
                                    sum(object_aggregates.page_views_count) as view_count,
                                    sum(object_aggregates.blog_articles_count) as blog_count,
                                    sum(object_aggregates.news_articles_count) as news_count
                             FROM object_aggregates
                             WHERE object_aggregates.date >= current_timestamp - interval '#{def_count_days} days' AND
                                   object_aggregates.aggregatable_type = 'Person'
                             GROUP BY object_aggregates.aggregatable_id
                             ORDER BY view_count DESC) aggregates
                            ON people.id=aggregates.aggregatable_id
    WHERE roles.role_type = ?
      AND (roles.startdate <= ?
            AND roles.enddate >= ?)
 ORDER BY #{order} #{lim};",
                        chamber, Date.today, Date.today])
  end

  ##
  # This class method creates a Hash containing data about which
  # senators and representatives have replied to messages, never
  # been sent a message, and have been sent messages but haven't
  # replied to any.
  #
  # @return {Hash} object containing metadata about all replies
  #
  def self.get_email_reply_summary(congresses=[Settings.default_congress])
    toReturn = {
        :count_total => 0,
        :count_replied => 0,
        :count_never_sent_letter => 0,
        :count_have_not_replied => 0,
        :list_replied => [],
        :list_never_sent_letter => [],
        :list_have_not_replied => []
    }
    Person.all().each {|person|
      if person.congresses?(congresses)
        toPush = person.get_email_reply_summary
        if toPush['status'] == 'REPLIED'
          toReturn[:list_replied].push(toPush)
          toReturn[:count_replied] += 1
        elsif toPush['status'] == 'NEVER SENT A LETTER'
          toReturn[:list_never_sent_letter].push(toPush)
          toReturn[:count_never_sent_letter] += 1
        else
          toReturn[:list_have_not_replied].push(toPush)
          toReturn[:count_have_not_replied] += 1
        end
      end
    }
    toReturn[:count_total] = toReturn[:count_replied] + toReturn[:count_never_sent_letter] + toReturn[:count_have_not_replied]
    return toReturn
  end

  # Battle Royale
  def self.find_all_by_most_tracked_for_range(range, options)
    range = 630720000 if range.nil?

    # this prevents sql injection
    possible_orders = ["bookmark_count_1 desc", "bookmark_count_1 asc",
                       "p_approval_avg desc", "p_approval_avg asc", "p_approval_count desc",
                       "p_approval_count asc", "total_comments asc", "total_comments desc"]
    order = options[:order] ||= "bookmark_count_1 desc"
    search = options[:search]

    if possible_orders.include?(order)
      limit = options[:limit] ||= 20
      offset = options[:offset] ||= 0
      person_type = options[:person_type] ||= "Sen."
      not_null_check = order.split(' ').first

      if search
        find_by_sql(["select people.*, rank(fti_names, ?, 1) as tsearch_rank, current_period.bookmark_count_1 as bookmark_count_1,
                       comments_total.total_comments as total_comments, papps.p_approval_count as p_approval_count,
                       papps.p_approval_avg as p_approval_avg,
                       previous_period.bookmark_count_2 as bookmark_count_2
                       FROM people
                       INNER JOIN (select bookmarks.bookmarkable_id  as people_id_1,
                                   count(bookmarks.bookmarkable_id) as bookmark_count_1
                                   FROM bookmarks
                                       WHERE created_at > ? AND
                                             created_at <= ?
                                   GROUP BY people_id_1) current_period
                       ON people.id=current_period.people_id_1
                       LEFT OUTER JOIN (select comments.commentable_id as people_id_5,
                                        count(comments.*) as total_comments
                                    FROM comments
                                        WHERE created_at > ? AND
                                        comments.commentable_type = 'Person'
                                    GROUP BY comments.commentable_id) comments_total
                       ON people.id=comments_total.people_id_5
                       LEFT OUTER JOIN (select bookmarks.bookmarkable_id as people_id_2,
                                        count(bookmarks.bookmarkable_id) as bookmark_count_2
                                        FROM bookmarks
                                             WHERE created_at > ? AND
                                                   created_at <= ?
                                        GROUP BY people_id_2) previous_period
                       ON people.id=previous_period.people_id_2
                       LEFT OUTER JOIN (select person_approvals.person_id as p_approval_id,
                                        count(person_approvals.id) as p_approval_count,
                                        avg(person_approvals.rating) as p_approval_avg
                                       FROM person_approvals
                                           WHERE person_approvals.created_at > '#{range.seconds.ago.to_s(:db)}'
                                       GROUP BY p_approval_id) papps
                       ON p_approval_id = people.id
                       WHERE #{not_null_check} is not null AND people.title = '#{person_type}'
                       AND  people.fti_names @@ to_tsquery('english', ?)
                       ORDER BY #{order} LIMIT #{limit} OFFSET #{offset}",
                     search, range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago, range.seconds.ago, search])



      else
        find_by_sql(["select people.*, current_period.bookmark_count_1 as bookmark_count_1,
                       comments_total.total_comments as total_comments, papps.p_approval_count as p_approval_count,
                       papps.p_approval_avg as p_approval_avg,
                       previous_period.bookmark_count_2 as bookmark_count_2
                       FROM people
                       INNER JOIN (select bookmarks.bookmarkable_id  as people_id_1,
                                   count(bookmarks.bookmarkable_id) as bookmark_count_1
                                   FROM bookmarks
                                       WHERE created_at > ? AND
                                             created_at <= ?
                                   GROUP BY people_id_1) current_period
                       ON people.id=current_period.people_id_1
                       LEFT OUTER JOIN (select comments.commentable_id as people_id_5,
                                        count(comments.*) as total_comments
                                    FROM comments
                                        WHERE created_at > ? AND
                                        comments.commentable_type = 'Person'
                                    GROUP BY comments.commentable_id) comments_total
                       ON people.id=comments_total.people_id_5
                       LEFT OUTER JOIN (select bookmarks.bookmarkable_id as people_id_2,
                                        count(bookmarks.bookmarkable_id) as bookmark_count_2
                                        FROM bookmarks
                                             WHERE created_at > ? AND
                                                   created_at <= ?
                                        GROUP BY people_id_2) previous_period
                       ON people.id=previous_period.people_id_2
                       LEFT OUTER JOIN (select person_approvals.person_id as p_approval_id,
                                        count(person_approvals.id) as p_approval_count,
                                        avg(person_approvals.rating) as p_approval_avg
                                       FROM person_approvals
                                           WHERE person_approvals.created_at > '#{range.seconds.ago.to_s(:db)}'
                                       GROUP BY p_approval_id) papps
                       ON p_approval_id = people.id
                       WHERE #{not_null_check} is not null AND people.title = '#{person_type}'
                       ORDER BY #{order} LIMIT #{limit} OFFSET #{offset}",
                     range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago, range.seconds.ago])
      end
    else
      return []
    end
  end

  def self.count_all_by_most_tracked_for_range(range, options)
    range = 630720000 if range.nil?

    # this prevents sql injection
    possible_orders = ["bookmark_count_1 desc", "bookmark_count_1 asc",
                       "p_approval_avg desc", "p_approval_avg asc", "p_approval_count desc",
                       "p_approval_count asc", "total_comments asc", "total_comments desc"]
    logger.info options.to_yaml
    order = options[:order] ||= "bookmark_count_1 desc"
    search = options[:search]

    if possible_orders.include?(order)
      limit = options[:limit] ||= 20
      offset = options[:offset] ||= 0
      person_type = options[:person_type] ||= "Sen."
      not_null_check = order.split(' ').first

      if search
        count_by_sql(["select count(people.*)
                       FROM people
                       INNER JOIN (select bookmarks.bookmarkable_id  as people_id_1,
                                   count(bookmarks.bookmarkable_id) as bookmark_count_1
                                   FROM bookmarks
                                       WHERE created_at > ? AND
                                             created_at <= ?
                                   GROUP BY people_id_1) current_period
                       ON people.id=current_period.people_id_1
                       LEFT OUTER JOIN (select comments.commentable_id as people_id_5,
                                        count(comments.*) as total_comments
                                    FROM comments
                                        WHERE created_at > ? AND
                                        comments.commentable_type = 'Person'
                                    GROUP BY comments.commentable_id) comments_total
                       ON people.id=comments_total.people_id_5
                       LEFT OUTER JOIN (select bookmarks.bookmarkable_id as people_id_2,
                                        count(bookmarks.bookmarkable_id) as bookmark_count_2
                                        FROM bookmarks
                                             WHERE created_at > ? AND
                                                   created_at <= ?
                                        GROUP BY people_id_2) previous_period
                       ON people.id=previous_period.people_id_2
                       LEFT OUTER JOIN (select person_approvals.person_id as p_approval_id,
                                        count(person_approvals.id) as p_approval_count,
                                        avg(person_approvals.rating) as p_approval_avg
                                       FROM person_approvals
                                           WHERE person_approvals.created_at > '#{range.seconds.ago.to_s(:db)}'
                                       GROUP BY p_approval_id) papps
                       ON p_approval_id = people.id
                       WHERE #{not_null_check} is not null AND people.title = '#{person_type}'
                       AND  people.fti_names @@ to_tsquery('english', ?)
                       LIMIT #{limit} OFFSET #{offset}",
                      range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago, range.seconds.ago, search])



      else
        count_by_sql(["select count(people.*)
                       FROM people
                       INNER JOIN (select bookmarks.bookmarkable_id  as people_id_1,
                                   count(bookmarks.bookmarkable_id) as bookmark_count_1
                                   FROM bookmarks
                                       WHERE created_at > ? AND
                                             created_at <= ?
                                   GROUP BY people_id_1) current_period
                       ON people.id=current_period.people_id_1
                       LEFT OUTER JOIN (select comments.commentable_id as people_id_5,
                                        count(comments.*) as total_comments
                                    FROM comments
                                        WHERE created_at > ? AND
                                        comments.commentable_type = 'Person'
                                    GROUP BY comments.commentable_id) comments_total
                       ON people.id=comments_total.people_id_5
                       LEFT OUTER JOIN (select bookmarks.bookmarkable_id as people_id_2,
                                        count(bookmarks.bookmarkable_id) as bookmark_count_2
                                        FROM bookmarks
                                             WHERE created_at > ? AND
                                                   created_at <= ?
                                        GROUP BY people_id_2) previous_period
                       ON people.id=previous_period.people_id_2
                       LEFT OUTER JOIN (select person_approvals.person_id as p_approval_id,
                                        count(person_approvals.id) as p_approval_count,
                                        avg(person_approvals.rating) as p_approval_avg
                                       FROM person_approvals
                                           WHERE person_approvals.created_at > '#{range.seconds.ago.to_s(:db)}'
                                       GROUP BY p_approval_id) papps
                       ON p_approval_id = people.id
                       WHERE #{not_null_check} is not null AND people.title = '#{person_type}'
                       LIMIT #{limit} OFFSET #{offset}",
                      range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago, range.seconds.ago])
      end
    else
      return []
    end
  end

  def self.calculate_and_save_party_votes
    update_query = ["UPDATE people
                     SET total_session_votes=votes_agg.total_votes,
                         votes_democratic_position=votes_agg.votes_democratic_position,
                         votes_republican_position=votes_agg.votes_republican_position
                     FROM
                  (SELECT people.id as person_id,
                           total_votes.total_votes AS total_votes,
                           dem_position.votes_democratic_position as votes_democratic_position,
                           rep_position.votes_republican_position as votes_republican_position
    FROM people
    LEFT OUTER JOIN roles on roles.person_id=people.id
    LEFT OUTER JOIN
      (SELECT DISTINCT(roll_call_votes.person_id) as p_id, count(DISTINCT roll_calls.id) AS total_votes
      FROM roll_calls
      LEFT OUTER JOIN bills ON bills.id = roll_calls.bill_id
      INNER JOIN roll_call_votes ON roll_calls.id = roll_call_votes.roll_call_id
      WHERE roll_call_votes.vote != '0' AND bills.session = ?
      GROUP BY roll_call_votes.person_id) total_votes ON total_votes.p_id=people.id
    LEFT OUTER JOIN
      (SELECT DISTINCT(roll_call_votes.person_id) as p_id, count(DISTINCT roll_calls.id) AS votes_democratic_position
      FROM roll_calls
      LEFT OUTER JOIN bills ON bills.id = roll_calls.bill_id
      INNER JOIN roll_call_votes ON roll_calls.id = roll_call_votes.roll_call_id
      WHERE ((roll_calls.democratic_position = true AND vote = '+') OR (roll_calls.democratic_position = false AND vote = '-'))
      AND bills.session = ?
      GROUP BY roll_call_votes.person_id) dem_position ON dem_position.p_id=people.id
    LEFT OUTER JOIN
      (SELECT DISTINCT(roll_call_votes.person_id) as p_id, count(DISTINCT roll_calls.id) AS votes_republican_position
      FROM roll_calls
      LEFT OUTER JOIN bills ON bills.id = roll_calls.bill_id
      INNER JOIN roll_call_votes ON roll_calls.id = roll_call_votes.roll_call_id
      WHERE ((roll_calls.republican_position = true AND vote = '+') OR (roll_calls.republican_position = false AND vote = '-'))
      AND bills.session = ?
      GROUP BY roll_call_votes.person_id) rep_position ON rep_position.p_id=people.id
    WHERE roles.startdate <= ? AND roles.enddate >= ?) votes_agg
    WHERE people.id=votes_agg.person_id", Settings.default_congress, Settings.default_congress, Settings.default_congress, Date.today, Date.today]


    ActiveRecord::Base.connection.execute(sanitize_sql_array(update_query))
  end

  def self.list_by_votes_with_party_ranking(chamber = 'house', party = 'Democrat')
    role_type = (chamber == 'house') ? 'Rep.' : 'Sen.'

    # find_by_sql(["SELECT people.*,
    #                       CASE WHEN people.party = 'Democrat' THEN (people.votes_democratic_position::real/people.total_session_votes::real)::real
    #                            WHEN people.party = 'Republican' THEN (people.votes_republican_position::real/people.total_session_votes::real)::real
    #                            ELSE 0
    #                       END as votes_with_party_percentage::real  FROM people
    #                    LEFT OUTER JOIN roles on roles.person_id=people.id
    #                    WHERE people.party = ? AND roles.startdate <= ? AND roles.enddate >= ?
    #                      AND people.title = ?
    #                   ORDER BY votes_with_party_percentage DESC", party, Date.today, Date.today, role_type])

    peeps = find_by_sql(["SELECT people.*, 0.0 as votes_with_party_percentage FROM people
                       LEFT OUTER JOIN roles on roles.person_id=people.id
                       WHERE people.party = ? AND roles.startdate <= ? AND roles.enddate >= ?
                         AND people.title = ?
                      ORDER BY votes_with_party_percentage DESC", party, Date.today, Date.today, role_type])

    if party == 'Democrat'
      peeps.collect! {|p|
        p.votes_with_party_percentage = p.total_session_votes ? (p.votes_democratic_position.to_f/p.total_session_votes.to_f) * 100 : 0
        p
      }
    else # TODO this assumes all non-dems are republicans
      peeps.collect! {|p|
        p.votes_with_party_percentage = p.total_session_votes ? (p.votes_republican_position.to_f/p.total_session_votes.to_f) * 100 : 0
        p
      }
    end

    peeps.sort {|a,b| b.votes_with_party_percentage <=> a.votes_with_party_percentage}
  end

  def self.random(role, limit=3, congress=109)
    Person.find_by_sql ["SELECT * FROM (SELECT random(), people.* FROM people LEFT OUTER JOIN roles on roles.person_id=people.id WHERE roles.role_type = ? AND roles.startdate <= ? AND roles.enddate >= ? ORDER BY 1) as peeps LIMIT ?;", role, OpenCongress::Application::CONGRESS_START_DATES[congress], OpenCongress::Application::CONGRESS_START_DATES[congress], limit]
  end

  def self.find_all_by_last_name_ci_and_state(name, state)
    Person.includes(:roles).where(["lower(lastname) = ? AND people.state = ?", name.downcase, state])
  end

  def self.find_all_by_first_name_ci_and_last_name_ci_and_state(first, last, state)
    Person.includes(:roles).where(["lower(lastname) = ? AND (lower(firstname) = ? OR lower(nickname) = ?) AND people.state = ?", last.downcase, first.downcase, first.downcase, state])
  end

  def self.find_by_first_name_ci_and_last_name_ci(first,last)
    Person.includes(:roles).where(["lower(lastname) = ? AND (lower(firstname) = ? OR lower(nickname) = ?)", last.downcase, first.downcase, first.downcase])
  end

  def self.find_all_by_last_name_ci(name)
    Person.includes(:roles).where(["lower(lastname) = ?", name.downcase])
  end

  ##
  # In this case address is free-form. Can be as simple as a state or
  # zipcode, though those will yield less accurate results.
  def self.find_current_congresspeople_by_address(address)
    dsts = District.from_address(address)
    reps = dsts.map(&:rep).uniq.compact
    sens = dsts.flat_map(&:sens).uniq
    return [ sens, reps ]
  end

  def self.find_current_representative_by_state_and_district(state, district)
    Person.includes(:roles).where(
      ["people.state = ? AND people.district = '?' AND roles.role_type='rep' AND roles.enddate > ?", state, district, Date.today]
    ).references(:roles).first
  end

  ##
  # This returns a pair of arrays: [ [sen1, sen2], [rep1, ... repN] ]
  # Callers must check the length of the rep array in case
  # the zip5 was not specific enough.
  def self.find_current_congresspeople_by_zipcode(zip5, zip4=nil)
    if zip5.present? && zip4.present?
      lat, lng = MultiGeocoder.coordinates("#{zip5}-#{zip4}")
      legs = Congress.legislators_locate(lat, lng).results rescue []
    elsif zip5.present?
      legs = Congress.legislators_locate(zip5).results rescue []
    else
      legs = []
    end

    #ap(legs)

    return nil if legs.empty?

    legs = Person.where(:id => legs.map{ |l| l.govtrack_id })
    [legs.select{ |l| l.title == 'Sen.' },
     legs.select{ |l| %w(Del. Rep.).include? l.title }]
  end

  def self.find_current_senators_by_state(state)
    Person.on_date(Date.today).where('people.state' => state, 'roles.role_type' => 'sen')
  end

  def self.find_current_representatives_by_state_and_district(state, district)
    Person.on_date(Date.today).where(:title => %w[Rep. Del.], :state => state, :district => district.to_s)
  end

  # return bill actions since last X
  def self.find_user_data_for_tracked_person(person, current_user)
    time_since = current_user.previous_login_date || 20.days.ago
    time_since = 200.days.ago if Rails.env.development?
    find_by_id(person.id,
               :select => "people.*,
                                (select count(roll_call_votes.id) FROM roll_call_votes
                                     INNER JOIN (select roll_calls.id, roll_calls.date FROM roll_calls WHERE roll_calls.date > '#{time_since.to_s(:db)}') rcs
                                         ON rcs.id = roll_call_votes.roll_call_id
                                     WHERE person_id = #{person.id} ) as votes_count,
                                (select count(commentaries.id) FROM commentaries
                                     WHERE commentaries.commentariable_id = #{person.id},
                                       AND commentariable_type = 'Person'
                                       AND commentaries.is_ok = 't'
                                       AND commentaries.is_news='f'
                                       AND commentaries.date > '#{time_since.to_s(:db)}'  ) as blog_count,
                                (select count(commentaries.id) FROM commentaries
                                    WHERE commentaries.commentariable_id = #{person.id},
                                      AND commentariable_type = 'Person'
                                      AND commentaries.is_ok = 't'
                                      AND commentaries.is_news='t'
                                      AND commentaries.date > '#{time_since.to_s(:db)}' ) as newss_count,
                                (select count(comments.id) FROM comments
                                     WHERE comments.created_at > '#{time_since.to_s(:db)}'
                                       AND comments.commentable_type='Person'
                                       AND comments.commentable_id = #{person.id}) as comment_count")
  end

  # return bill actions since last X
  def self.find_changes_since_for_senators_tracked(current_user)
    time_since = current_user.previous_login_date || 20.days.ago
    time_since = 200.days.ago if Rails.env.development?
    ids = current_user.senator_bookmarks.collect{|p| p.bookmarkable_id}
    return [] if ids.empty?
    find_by_sql("select people.*, total_actions.action_count as votes_count,
                                total_blogs.blog_count as blogss_count, total_news.news_count as newss_count,
                                total_comments.comments_count as commentss_count from people
                                LEFT OUTER JOIN (select count(roll_call_votes.id) as action_count,
                                    roll_call_votes.person_id as person_id_1 FROM roll_call_votes
                                    INNER JOIN ( select roll_calls.id, roll_calls.date FROM roll_calls WHERE roll_calls.date > '#{time_since.to_s(:db)}') rcs
                                    ON rcs.id = roll_call_votes.roll_call_id
                                    WHERE roll_call_votes.person_id in (#{ids.join(",")})
                                    group by person_id_1) total_actions ON
                                    total_actions.person_id_1 = people.id
                                LEFT OUTER JOIN (select count(commentaries.id) as blog_count,
                                    commentaries.commentariable_id as person_id_2 FROM commentaries WHERE
                                    commentaries.commentariable_id IN (#{ids.join(",")}) AND
                                    commentaries.commentariable_type='Person' AND
                                    commentaries.is_ok = 't' AND commentaries.is_news='f' AND
                                    commentaries.date > '#{time_since.to_s(:db)}'
                                    group by commentaries.commentariable_id)
                                    total_blogs ON total_blogs.person_id_2 = people.id
                                LEFT OUTER JOIN (select count(commentaries.id) as news_count,
                                    commentaries.commentariable_id as person_id_3 FROM commentaries WHERE
                                    commentaries.commentariable_id IN (#{ids.join(",")}) AND
                                    commentaries.commentariable_type='Person' AND
                                    commentaries.is_ok = 't' AND commentaries.is_news='t' AND
                                    commentaries.date > '#{time_since.to_s(:db)}'
                                    group by commentaries.commentariable_id)
                                    total_news ON total_news.person_id_3 = people.id
                                LEFT OUTER JOIN (select count(comments.id) as comments_count,
                                    comments.commentable_id as person_id_4 FROM comments WHERE
                                    comments.created_at > '#{time_since.to_s(:db)}' AND
                                    comments.commentable_id in (#{ids.join(",")}) AND
                                    comments.commentable_type = 'Bill' GROUP BY comments.commentable_id)
                                    total_comments ON total_comments.person_id_4 = people.id where people.id IN (#{ids.join(",")})")
  end

  # return bill actions since last X
  def self.find_changes_since_for_representatives_tracked(current_user)
    time_since = current_user.previous_login_date || 20.days.ago
    time_since = 200.days.ago if Rails.env.development?
    ids = current_user.representative_bookmarks.collect{|p| p.bookmarkable_id}
    return [] if ids.empty?
    find_by_sql("select people.*, total_actions.action_count as votes_count,
                                total_blogs.blog_count as blogss_count, total_news.news_count as newss_count,
                                total_comments.comments_count as commentss_count from people
                                LEFT OUTER JOIN (select count(roll_call_votes.id) as action_count,
                                    roll_call_votes.person_id as person_id_1 FROM roll_call_votes
                                    INNER JOIN ( select roll_calls.id, roll_calls.date FROM roll_calls WHERE roll_calls.date > '#{time_since.to_s(:db)}') rcs
                                    ON rcs.id = roll_call_votes.roll_call_id
                                    WHERE roll_call_votes.person_id in (#{ids.join(",")})
                                    group by person_id_1) total_actions ON
                                    total_actions.person_id_1 = people.id
                                LEFT OUTER JOIN (select count(commentaries.id) as blog_count,
                                    commentaries.commentariable_id as person_id_2 FROM commentaries WHERE
                                    commentaries.commentariable_id IN (#{ids.join(",")}) AND
                                    commentaries.commentariable_type='Person' AND
                                    commentaries.is_ok = 't' AND commentaries.is_news='f'  AND
                                    commentaries.date > '#{time_since.to_s(:db)}'
                                    group by commentaries.commentariable_id)
                                    total_blogs ON total_blogs.person_id_2 = people.id
                                LEFT OUTER JOIN (select count(commentaries.id) as news_count,
                                    commentaries.commentariable_id as person_id_3 FROM commentaries WHERE
                                    commentaries.commentariable_id IN (#{ids.join(",")}) AND
                                    commentaries.commentariable_type='Person' AND
                                    commentaries.is_ok = 't' AND commentaries.is_news='t'  AND
                                    commentaries.date > '#{time_since.to_s(:db)}'
                                    group by commentaries.commentariable_id)
                                    total_news ON total_news.person_id_3 = people.id
                                LEFT OUTER JOIN (select count(comments.id) as comments_count,
                                    comments.commentable_id as person_id_4 FROM comments WHERE
                                    comments.created_at > '#{time_since.to_s(:db)}' AND
                                    comments.commentable_id in (#{ids.join(",")}) AND
                                    comments.commentable_type = 'Bill' GROUP BY comments.commentable_id)
                                    total_comments ON total_comments.person_id_4 = people.id where people.id IN (#{ids.join(",")})")
  end

  def self.find_by_most_commentary(type = 'news', person_type = 'rep', num = 5, since = Settings.default_count_time)
    title = (person_type == 'rep') ? 'Rep.' : 'Sen.'
    is_news = (type == "news") ? true : false

    Person.find_by_sql(["SELECT people.*, top_people.article_count AS article_count FROM people
                       INNER JOIN
                       (SELECT commentaries.commentariable_id, count(commentaries.commentariable_id) AS article_count
                        FROM commentaries
                        WHERE commentaries.commentariable_type='Person' AND
                              commentaries.date > ? AND
                              commentaries.is_news=? AND
                              commentaries.is_ok='t'
                        GROUP BY commentaries.commentariable_id
                        ORDER BY article_count DESC) top_people
                       ON people.id=top_people.commentariable_id
                       WHERE people.title = ?
                       ORDER BY article_count DESC
                       LIMIT ?",
                        since.ago, is_news, title, num])
  end

  def self.top20_commentary(type = 'news', person_type = 'rep')
    people = Person.find_by_most_commentary(type, person_type, num = 20)

    date_method = :"entered_top_#{type}"
    (people.select {|p| p.stats.send(date_method).nil? }).each do |pv|
      pv.stats.send("#{date_method}=", Time.now)
      pv.save
    end

    (people.sort { |p1, p2| p2.stats.send(date_method) <=> p1.stats.send(date_method) })
  end

  def self.representatives(congress = Settings.default_congress, order_by = 'name')
    Person.find_by_role_type('rep', congress, order_by)
  end

  def self.voting_representatives
    Person.includes(:roles).where(
      [ "roles.role_type=? AND roles.enddate > ? AND roles.state NOT IN (?)",
        'rep',  Date.today, @@NONVOTING_TERRITORIES ]).references(:roles).order("people.lastname")
  end

  def self.senators(congress = Settings.default_congress, order_by = 'name')
    Person.find_by_role_type('sen', congress, order_by)
  end

  def self.find_by_role_type(role_type, congress, order_by)
    case order_by
      when 'state'
        order = "people.state, people.district"
      else
        order = "people.lastname"
    end

    Person.includes(:roles).where(
      [ "roles.role_type=? AND roles.enddate > ? ",
        role_type,  Date.today ]).references(:roles).order(order)
  end

  def self.all_sitting
    self.senators.concat(self.representatives)
  end

  def self.all_voting
    self.senators.concat(self.voting_representatives)
  end

  def self.top20_viewed(person_type = nil)
    case person_type
      when 'sen'
        people = ObjectAggregate.popular('Person', Settings.default_count_time, 540).select{|p| p.title == 'Sen.'}[0..20]
      when 'rep'
        people = ObjectAggregate.popular('Person', Settings.default_count_time, 540).select{|p| p.title == 'Rep.'}[0..20]
      else
        people = ObjectAggregate.popular('Person')
    end

    (people.select {|p| p.stats.entered_top_viewed.nil? }).each do |pv|
      pv.stats.entered_top_viewed = Time.now
      pv.save
    end

    if person_type
      case person_type
        when 'sen'
          people = people.select { |p| p.senator? }
        when 'rep'
          people = people.select { |p| p.representative? }
      end
    end

    (people.sort { |p1, p2| p2.stats.entered_top_viewed <=> p1.stats.entered_top_viewed })
  end

  # Return an array of people with an email address, and an
  # array of those without
  def self.email_lists(people)
    people.partition {|p| p.email }
  end

  def self.full_text_search(q, options = {})
    current = options[:only_current] ? " AND (people.title='Rep.' OR people.title='Sen.' OR people.title='Del.')" : ""

    people = Person.paginate_by_sql(["SELECT people.*, rank(fti_names, ?, 1) as tsearch_rank FROM people WHERE people.fti_names @@ to_tsquery('english', ?) #{current} ORDER BY people.lastname", q, q], :per_page => Settings.default_search_page_size, :page => options[:page])
    people
  end

  # the following isn't called on an instance but rather, static-ly (sp?)
  def self.expire_meta_commentary_fragments
    person_types = ['sen', 'rep']
    commentary_types = ['news', 'blog']
    fragments = []

    person_types.each do |pt|
      commentary_types.each do |ct|
        [7, 14, 30].each do |d|
          fragments << "person_meta_#{pt}_most_#{ct}_#{d.days}"
        end
      end
    end

    FragmentCacheSweeper::expire_fragments(fragments)
  end

  #----- INSTANCE

  public

  def sponsored_bills_passed
    bills.joins(:actions).where('actions.action_type = ?', 'enacted')
  end

  def cosponsored_bills_passed
    bills_cosponsored.joins(:actions).where('actions.action_type = ?', 'enacted')
  end

  def congresses_active
    current_congress = UnitedStates::Congress.congress_for_year(Date.today.year)
    years = roles.flat_map { |r| (r.startdate.year..r.enddate.year).to_a[0..5] }
    congresses = years.map{ |y| UnitedStates::Congress.congress_for_year(y) }.uniq
    congresses.select{ |c| c <= current_congress }
  end

  def photo_path(style = :full, missing = :check_missing)
    if style == :thumb
      photo_path = "photos/thumbs_42/#{id}.png"
    elsif style == :medium
      photo_path = "photos/thumbs_73/#{id}.png"
    else
      photo_path = "photos/thumbs_102/#{id}.png" # :full
    end

    if missing == :ignore_missing || File.exists?(File.join(Rails.root, 'public', 'images', photo_path))
      return photo_path
    else
      return "missing-#{style}.png"
    end
  end

  def recent_videos(count)
    self.videos.limit(2)
  end

  def display_object_name
    @@DISPLAY_OBJECT_NAME
  end

  def atom_id_as_feed
    "tag:opencongress.org,2007:/person_feed/#{id}"
  end

  def atom_id_as_entry
    "tag:opencongress.org,2007:/person/#{id}"
  end

  def oc_approval_rating
    self.person_approvals.average(:rating).round * 10
  end

  def oc_user_comments
    self.comments.count
  end

  def oc_users_tracking
    self.bookmarks.count
  end

  def to_api_xml
    self.to_xml(:include => [:recent_news, :recent_blogs, :oc_approval_rating])
  end

  def seated_name
    rope = [firstname]
    if middlename
      rope << ' ' << middlename
    end
    rope << ' ' << lastname
    if not party.nil? and not state.nil?
      rope << ' [' << party[0] << '-' << state << ']'
    end
    rope.join('')
  end

  def with_party
    self.party_votes.count
  end

  def against_party
    self.unabstained_roll_calls.count - self.party_votes.count
  end

  def against_party_percentage
    if self.unabstained_roll_calls.count > 0
      return self.against_party.to_f / self.unabstained_roll_calls.count.to_f * 100 if self.unabstained_roll_calls.count > 0
    else
      return 0.0
    end
  end

  def with_party_percentage
    if self.unabstained_roll_calls.count > 0
      return self.party_votes.count.to_f / self.unabstained_roll_calls.count.to_f * 100 if self.unabstained_roll_calls.count > 0
    else
      return 0.0
    end
  end

  def abstains_percentage
    if ( self.unabstained_roll_calls.count + self.abstained_roll_calls.count ) > 0
      self.abstained_roll_calls.count.to_f / ( self.unabstained_roll_calls.count.to_f + self.abstained_roll_calls.count.to_f )  * 100
    else
      return 0.0
    end
  end

  def to_light_xml(options = {})
    default_options = {:methods => [:oc_user_comments, :oc_users_tracking], :except => [:fti_names]}
    self.to_xml(default_options.merge(options))
  end

  def to_medium_xml(options = {})
    default_options = {:methods => [:oc_user_comments, :oc_users_tracking], :except => [:fti_names]}
    self.to_xml(default_options.merge(options))
  end

  def latest_role
    roles.order(:startdate).first
  end

  def sponsored_bills_rank
    b = Bill.sponsor_count
    number = 0
    rank = 0
    out_of = 0
    case self.title
    when 'Sen.'
      temp_rank = b.index(b.detect {|x| x[0].to_i == self.id})
      puts temp_rank
      if temp_rank
        number = b.values_at(temp_rank).first.last
        rank = temp_rank + 1
      end
      out_of = 100
    when 'Rep.'
      temp_rank = b.index(b.detect {|x| x[0].to_i == self.id})
      if temp_rank
        number = b.values_at(temp_rank).first.last
        rank = temp_rank + 1
      end
      out_of = 440
    end
    return [number,rank,out_of]
  end

  def co_sponsored_bills_rank
    b = Bill.cosponsor_count
    number = 0
    rank = 0
    out_of = 0
    case self.title
    when 'Sen.'
      temp_rank = b.index(b.detect {|x| x[0].to_i == self.id})
      if temp_rank
        number = b.values_at(temp_rank).first.last
        rank = temp_rank + 1
      end
      out_of = 100
    when 'Rep.'
      temp_rank = b.index(b.detect {|x| x[0].to_i == self.id})
      if temp_rank
        number = b.values_at(temp_rank).first.last
        rank = temp_rank + 1
      end
      out_of = 440
    end
    return [number,rank,out_of]
  end

  def abstain_rank
    b = RollCallVote.abstain_count
    number = 0
    rank = 0
    out_of = 0
    case self.title
    when 'Sen.'
      temp_rank = b.index(b.detect {|x| x[0].to_i == self.id})
      if temp_rank
        number = b.values_at(temp_rank).first.last
        rank = temp_rank + 1
      end
      out_of = 100
    when 'Rep.'
      temp_rank = b.index(b.detect {|x| x[0].to_i == self.id})
      if temp_rank
        number = b.values_at(temp_rank).first.last
        rank = temp_rank + 1
      end
      out_of = 440
    end
    return [number,rank,out_of]
  end

  def has_contact_webform?
    (!self.contact_webform.blank? && (self.contact_webform =~ /^http:\/\//)) ? true : false
  end

  ##
  # This method retrieves metadata of replies sent from
  # a representative or senator person to a user.
  #
  # @return {Hash} object containing metadata about replies
  #
  def get_email_reply_summary
    latest = nil
    first = nil
    thread_ids = Formageddon::FormageddonThread.where(formageddon_recipient_id:self.id).map{|p|p.id}
    count = 0

    unless thread_ids.empty?
      thread_ids= ContactCongressLettersFormageddonThread.where(formageddon_thread_id:thread_ids).map{|p|p.formageddon_thread_id}
      Formageddon::FormageddonLetter.where(formageddon_thread_id:thread_ids, direction:'TO_SENDER', status:'RECEIVED').each {|letter|
        count += 1
        first = letter if (first == nil || letter.created_at < first.created_at)
        latest = letter if (latest == nil || latest.created_at < letter.created_at)
      }
    end

    return  {
              'id' => self.id,
              'bioguideid' => self.bioguideid,
              'thomas_id' => self.thomas_id,
              'title' => self.title,
              'firstname' => self.firstname,
              'lastname' => self.lastname,
              'state' => self.state,
              'district' => self.district,
              'party' => self.party,
              'status' => if thread_ids.empty?
                            'NEVER SENT A LETTER'
                          else
                            latest.nil? ? 'NOT REPLIED' : 'REPLIED'
                          end,
              'first_reply_datetime' => first.nil? ? '' : first.created_at,
              'last_reply_datetime' => latest.nil? ? '' : latest.created_at,
              'total_replies' => count
            }
  end

  def has_wiki_link?
    if self.wiki_url.blank?
      return false
    else
      return true
    end
  end

  def wiki_url

    link = ""

    unless self.wiki_link
      link = "#{Settings.wiki_base_url}/#{firstname}_#{lastname}"
    else
      link = "#{Settings.wiki_base_url}/#{self.wiki_link.name}"
    end

    return link

  end

  def wiki_bio_summary
    article_name = self.wiki_link.nil? ? "#{firstname}_#{lastname}" : self.wiki_link.name

    bio = Wiki.biography_text_for(article_name)
    unless bio.blank?
      more_link = "<a class='wiki_bio_more' href='#{Settings.wiki_base_url}/#{article_name}\#Biography'>Read More...</a></p>"

      # get first two sections
      first = bio.index(/<br\s\/><br\s\/>/)
      if first
        second = bio.index(/<br\s\/><br\s\/>/, (first + 16))

        if second
          summary = bio[0..(second-1)]
          summary += " #{more_link}</p>"
        else
          summary = bio.gsub(/<\/p>/, " #{more_link}</p>")
        end
      else
        return nil
      end
    else
      return nil
    end

    summary
  end


  def last_x_bills(limit = 2)
     self.bills.find(:all, :limit => limit)
     #[]
  end

  def recent_activity(since = nil)
    items = []
    items << bills.find(:all, :include => :bill_titles, :limit => 20).to_a
    items.concat(votes(20).to_a)

    items.flatten!
    items = items.select {|x| x.sort_date >= since} if since
    items.sort! { |x,y| y.sort_date <=> x.sort_date }
    items
  end

  def recent_activity_mini_list(since = nil)
    host = URI.parse(Settings.base_url).host

    items = []
    self.recent_activity(since).each do |i|
      case i.class.name
      when 'Bill'
        items << {:sort_date => i.sort_date.to_date, :content => "Introduced Bill: #{i.typenumber} - #{i.title_official}", :link => {:host => host, :only_path => false, :controller => 'bill', :action => 'show', :id => i.ident}}
      when 'RollCallVote'
        if i.roll_call.bill
          items << {:sort_date => i.sort_date.to_date, :content => "Vote: '" + i.to_s + "' regarding " + i.roll_call.bill.typenumber, :link => {:host => host, :only_path => false, :controller => 'roll_call', :action => 'show', :id => i.roll_call}}
        else
          items << {:sort_date => i.sort_date.to_date, :content => "Vote: '" + i.to_s + "' on the question " + i.roll_call.question, :link => {:host => host, :only_path => false, :controller => 'roll_call', :action => 'show', :id => i.roll_call}}
        end
      end
    end
    items.group_by{|x| x[:sort_date]}.to_a.sort{|a,b| b[0]<=>a[0]}
  end



  # Returns the number of people tracking this bill, as well as suggestions of what other people
  # tracking this bill are also tracking.
  def tracking_suggestions
    # temporarily removing solr for now - June 2012
    return [0, {}]

    facet_results_hsh = {:my_people_tracked_facet => [], :my_issues_tracked_facet => [], :my_bills_tracked_facet => []}
    my_trackers = 0

    begin
      users = User.find_by_solr('placeholder:placeholder', :facets => {:fields => [:my_people_tracked, :my_issues_tracked, :my_bills_tracked], :browse => ["my_people_tracked:#{self.id}"], :limit => 6, :zeros => false, :sort =>  true}, :limit => 1)
    rescue
      return [0, {}] unless Rails.env == 'production'
      raise
    end

    facets = users.facets
    facet_results_ff = facets['facet_fields']
    if facet_results_ff && facet_results_ff != []

      facet_results_ff.each do |fkey, fvalue|
        facet_results = facet_results_ff[fkey]

        #solr running through acts as returns as a Hash, or an array if running through tomcat...hence this stuffs
        facet_results_temp_hash = Hash[*facet_results] unless facet_results.class.to_s == "Hash"
        facet_results_temp_hash = facet_results if facet_results.class.to_s == "Hash"

        facet_results_temp_hash.each do |key,value|
          if key == self.id.to_s && fkey == "my_people_tracked_facet"
            my_trackers = value
          else
            unless facet_results_hsh[fkey.to_sym].length == 5
              object = Person.find_by_id(key) if fkey == "my_people_tracked_facet"
              object = Subject.find_by_id(key) if fkey == "my_issues_tracked_facet"
              object = Bill.find_by_ident(key) if fkey == "my_bills_tracked_facet"
              facet_results_hsh[fkey.to_sym] << {:object => object, :trackers => value}
            end
          end
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

      return [my_trackers, facet_results_hsh]
    else
      return [my_trackers,{}]
    end
  end

  def support_suggestions
    # temporarily removing solr for now - June 2012
    return [0, {}]

    primary = "my_approved_reps_facet" if self.title == "Rep."
    primary = "my_approved_sens_facet" if self.title == "Sen."

    return [0,{}] if (self.title.blank? or primary.blank?)

    begin
      users = User.find_by_solr('placeholder:placeholder', :facets => {:fields => [:my_bills_supported, :my_approved_reps, :my_approved_sens, :my_disapproved_reps, :my_disapproved_sens, :my_bills_opposed],
                                                        :browse => ["#{primary.gsub('_facet', '')}:#{self.id}"],
                                                        :limit => 6, :zeros => false, :sort =>  true}, :limit => 1)
    rescue
      return [0, {}] unless Rails.env == 'production'
      raise
    end

    return parse_facets(users.facets, primary, ["my_approved_reps_facet","my_approved_sens_facet","my_disapproved_reps_facet","my_disapproved_sens_facet",
                                                                   "my_bills_supported_facet", "my_bills_opposed_facet"])

  end

  def oppose_suggestions
    # temporarily removing solr for now - June 2012
    return [0, {}]

    primary = "my_disapproved_reps_facet" if self.roles.first.role_type == "rep"
    primary = "my_disapproved_sens_facet" if self.roles.first.role_type == "sen"

    return [0,{}] if self.title.blank?

    begin
      users = User.find_by_solr('placeholder:placeholder', :facets => {:fields => [:my_bills_supported, :my_approved_reps, :my_approved_sens, :my_disapproved_reps, :my_disapproved_sens, :my_bills_opposed],
                                                        :browse => ["#{primary.gsub('_facet', '')}:#{self.id}"],
                                                        :limit => 6, :zeros => false, :sort =>  true}, :limit => 1)
    rescue
      return [0, {}] unless Rails.env == 'production'
      raise
    end

    return parse_facets(users.facets, primary, ["my_approved_reps_facet","my_approved_sens_facet","my_disapproved_reps_facet","my_disapproved_sens_facet",
                                                                 "my_bills_supported_facet", "my_bills_opposed_facet"])

  end

  def consecutive_years
    chamber_roles = self.roles.where(role_type:self.roles.first.role_type).order('enddate DESC')
    number_terms = chamber_roles.length

    if chamber_roles.first.enddate > Date.today
      return (Date.today.year - chamber_roles.last.startdate.year)
    else
      return (chamber_roles.first.enddate.year - chamber_roles.last.startdate.year)
    end
  end

  def in_a_valid_district?
    (representative? && district != '0')
  end

  def state_rel
    @state_rel ||= State.find_by_abbreviation(state)
  end

  def district_rel
    @district_rel ||= District.where(:district_number => district, :state_id => state_rel).try(:first) if state_rel
  end

  def parse_facets(facets, primary_facet, selected_facets)
    my_trackers = 0
    facet_results_hsh = {}
    selected_facets.each do |s|
      facet_results_hsh[s.to_sym] = []
    end
    facet_results_ff = facets['facet_fields']

    if facet_results_ff && facet_results_ff != []

      facet_results_ff.each do |fkey, fvalue|
        facet_results = facet_results_ff[fkey]
        #solr running through acts as returns as a Hash, or an array if running through tomcat...hence this stuffs
        facet_results_temp_hash = Hash[*facet_results] unless facet_results.class.to_s == "Hash"
        facet_results_temp_hash = facet_results if facet_results.class.to_s == "Hash"

        facet_results_temp_hash.each do |key,value|
          if key == self.id.to_s && fkey == primary_facet
            my_trackers = value
          else
            unless facet_results_hsh[fkey.to_sym].length == 5
              object = Bill.find_by_id(key) if fkey =~ /my_bills/
              object = Person.find_by_id(key) if object.nil?
              facet_results_hsh[fkey.to_sym] << {:object => object, :trackers => value}
            end
          end
        end
      end
    else
      return [my_trackers,{}]
    end

    unless facet_results_hsh.empty?
      #sort the hashes
      selected_facets.each do |s|
        facet_results_hsh[s.to_sym].sort!{|a,b| b[:trackers]<=>a[:trackers] }
      end

      return [my_trackers, facet_results_hsh]
    else
      return [my_trackers,{}]
    end
  end

  def commentary_count(type = 'news', since = Settings.default_count_time)
    return @attributes['article_count'] if @attributes['article_count']

    if type == 'news'
      news.where([ "commentaries.date > ?", since.ago]).size
    else
      blogs.where([ "commentaries.date > ?", since.ago]).size
    end
  end



  def representative_for_congress?(congress = Settings.default_congress )
    #may be able to simplify this as >= 400000
    not (roles.select { |r| r.role_type == 'rep' && r.startdate <= DateTime.parse(OpenCongress::Application::CONGRESS_START_DATES[congress]) && r.enddate >= DateTime.parse(OpenCongress::Application::CONGRESS_START_DATES[congress])  }.empty?)
  end

  def representative?
    not (roles.select { |r| r.role_type == 'rep' && r.startdate <= Date.today && r.enddate >= Date.today  }.empty?)
  end

  def votes?
    not @@NONVOTING_TERRITORIES.include?(state)
  end

  def senator_for_congress? (congress = Settings.default_congress)
    #may be able to simplify this as < 400000
    not (roles.select { |r| r.role_type == 'sen' && r.startdate <= DateTime.parse(OpenCongress::Application::CONGRESS_START_DATES[congress]) && r.enddate >= DateTime.parse(OpenCongress::Application::CONGRESS_START_DATES[congress])  }.empty?)
  end

  def senator?
    not (roles.select { |r| r.role_type == 'sen' && r.startdate <= Date.today && r.enddate >= Date.today  }.empty?)
  end

  def congress? (congress = Settings.default_congress)
    not (roles.select { |r| r.startdate <= DateTime.parse(OpenCongress::Application::CONGRESS_START_DATES[congress]) && r.enddate >= DateTime.parse(OpenCongress::Application::CONGRESS_START_DATES[congress])  }.empty?)
  end

  def congresses? (congresses = [Settings.default_congress])
    congresses.each {|c| if self.congress?(c) then return true end }
    return false
  end

  def belongs_to_major_party?
    ((party == 'Democrat') || (party == 'Republican'))
  end

  def party_and_state
    self.party.blank? ? "#{self.state}" : "#{self.party[0,1]}-#{self.state}"
  end

  def opposing_party
    if belongs_to_major_party?
      if party == 'Democrat'
        return 'Republican'
      else
        return 'Democrat'
      end
    else
      "N/A"
    end
  end

  def select_list_name
    "#{lastname}, #{firstname} (#{party_and_state})"
  end

  def short_name
    "#{title} " + lastname
  end

  def full_name
    "#{firstname} #{lastname}"
  end

  def title_full_name
    "#{title} " + full_name
  end

  def title_common
    return 'Senator' if senator?
    return 'Rep.' if representative?
    return ''
  end

  def title_long
    case self.title
      when 'Sen.'
        'Senator'
      when 'Rep.'
        'Representative'
    end
  end

  def title_for_share
    name
  end

  def title_full_name_party_state
    title_full_name + " " + party_and_state
  end

  def popular_name
    "#{nickname || firstname} #{lastname}"
  end

  def to_s
    name
  end

  def to_param
    if unaccented_name
      "#{id}_#{unaccented_name.gsub(/[^A-Za-z]+/i, '_').gsub(/\s/, '_')}"
    else
      "#{id}_#{popular_name.gsub(/[^A-Za-z]+/i, '_').gsub(/\s/, '_')}"
    end
  end

  def ident
    self.to_param
  end

  def rep_info
  foo = /(\[.*\])/.match(name)
  "#{foo.captures}"
  end
  def roles_sorted
    roles.sort { |r1, r2| r2.startdate <=> r1.startdate }
  end

  def consecutive_roles
    current_role = roles.first

    roles.select {|r| r.role_type == current_role.role_type }
  end

  def votes_together_list
    Person.find_by_sql(["SELECT * FROM oc_votes_together(?, ?)
                         AS (v_id integer, v_count bigint)
                         LEFT OUTER JOIN people ON v_id=people.id
                         ORDER BY v_count DESC", self.id, OpenCongress::Application::CONGRESS_START_DATES[Settings.default_congress]])
  end

  def votes_apart_list
    Person.find_by_sql(["SELECT * FROM oc_votes_apart(?, ?)
                         AS (v_id integer, v_count bigint)
                         LEFT OUTER JOIN people ON v_id=people.id
                         ORDER BY v_count DESC", self.id, OpenCongress::Application::CONGRESS_START_DATES[Settings.default_congress]])
  end

  def is_sitting?
    !latest_role.nil? && latest_role.enddate >= Date.today
  end

  def chamber
    return 'house' if title == 'Rep.'
    return 'senate' if title == 'Sen.'
  end

  def votes(num = -1)
    if num > 0
      roll_call_votes.limit(num)
    else
      roll_call_votes
    end
  end

  def roll_call_votes_for_congress(congress = Settings.default_congress)
    self.roll_call_votes.includes(:person).where([ "roll_calls.date > ?", OpenCongress::Application::CONGRESS_START_DATES[Settings.default_congress]])
  end

  def most_and_least_voting_similarities
    [self.votes_together_list, self.votes_apart_list]
  end

  def stats
    unless person_stats
      create_person_stats
    end

    person_stats
  end

  def users_tracking_from_state_count(state)
    return 0;
    User.count_by_solr("my_state:\"#{state}\"", :facets => {:browse => ["public_tracking:true", "my_state_f:\"#{state}\"", "my_people_tracked:#{self.id}"]})
  end

  def average_approval_from_state(state)
    return nil

    begin
      ids = User.find_id_by_solr("my_state:\"#{state}\"", :facets => {:browse => ["my_state_f:\"#{state}\"", "my_people_tracked:#{self.id}"]}, :limit => 5000)
    rescue
      return nil unless Rails.env == 'production'
      raise
    end

    rating = PersonApproval.average(:rating, :conditions => ["user_id in (?)", ids.results])
    if rating
      return (rating * 10.00).round
    else
      return nil
    end
  end

  def average_approval_state
    average_approval_from_state(self.state)
  end

  def contrib_for_interest_group(num = 10, cycle = Settings.current_opensecrets_cycle)
    igs = CrpInterestGroup.find_by_sql(["SELECT crp_interest_groups.*, top_ind_igs.ind_contrib_total, top_pac_igs.pac_contrib_total, (COALESCE(top_ind_igs.ind_contrib_total, 0) + COALESCE(top_pac_igs.pac_contrib_total, 0)) AS contrib_total FROM crp_interest_groups
    LEFT JOIN
      (SELECT crp_interest_group_osid, SUM(crp_contrib_individual_to_candidate.amount)::integer as ind_contrib_total
      FROM crp_contrib_individual_to_candidate
      WHERE cycle=? AND recipient_osid=? AND crp_contrib_individual_to_candidate.contrib_type IN ('10', '11', '15 ', '15', '15E', '15J', '22Y')
      GROUP BY crp_interest_group_osid)
        top_ind_igs ON crp_interest_groups.osid=top_ind_igs.crp_interest_group_osid
    LEFT JOIN
      (SELECT crp_interest_group_osid, SUM(crp_contrib_pac_to_candidate.amount)::integer as pac_contrib_total
      FROM crp_contrib_pac_to_candidate
      WHERE cycle=? AND recipient_osid=?
      GROUP BY crp_interest_group_osid)
        top_pac_igs ON crp_interest_groups.osid=top_pac_igs.crp_interest_group_osid
    ORDER BY contrib_total DESC
    LIMIT ?", cycle, osid, cycle, osid, num])
  end

  def top_interest_groups(num = 10, cycle = Settings.current_opensecrets_cycle)
    igs = CrpInterestGroup.find_by_sql(["SELECT crp_interest_groups.*, top_ind_igs.ind_contrib_total, top_pac_igs.pac_contrib_total, (COALESCE(top_ind_igs.ind_contrib_total, 0) + COALESCE(top_pac_igs.pac_contrib_total, 0)) AS contrib_total FROM crp_interest_groups
    LEFT JOIN
      (SELECT crp_interest_group_osid, SUM(crp_contrib_individual_to_candidate.amount)::integer as ind_contrib_total
      FROM crp_contrib_individual_to_candidate
      WHERE cycle=?
        AND recipient_osid=?
        AND crp_contrib_individual_to_candidate.contrib_type IN ('10', '11', '15 ', '15', '15E', '15J', '22Y')
      GROUP BY crp_interest_group_osid)
        top_ind_igs ON crp_interest_groups.osid=top_ind_igs.crp_interest_group_osid
    LEFT JOIN
      (SELECT crp_interest_group_osid, SUM(crp_contrib_pac_to_candidate.amount)::integer as pac_contrib_total
      FROM crp_contrib_pac_to_candidate
      WHERE cycle=?
        AND recipient_osid=?
        AND contrib_type IN ('24K', '24R', '24Z')
      GROUP BY crp_interest_group_osid)
        top_pac_igs ON crp_interest_groups.osid=top_pac_igs.crp_interest_group_osid
    ORDER BY contrib_total DESC
    LIMIT ?", cycle, osid, cycle, osid, num])
  end

  def top_industries(num = 10, cycle = Settings.current_opensecrets_cycle)
    CrpIndustry.find_by_sql(["SELECT crp_industries.*, top_ind_is.ind_contrib_total, top_pac_is.pac_contrib_total, (COALESCE(top_ind_is.ind_contrib_total, 0) + COALESCE(top_pac_is.pac_contrib_total, 0)) AS contrib_total FROM crp_industries
    LEFT JOIN
      (SELECT crp_industries.id, SUM(crp_contrib_individual_to_candidate.amount) as ind_contrib_total
      FROM crp_industries
      INNER JOIN crp_interest_groups ON crp_industries.id=crp_interest_groups.crp_industry_id
      INNER JOIN crp_contrib_individual_to_candidate ON crp_interest_groups.osid=crp_contrib_individual_to_candidate.crp_interest_group_osid
      WHERE crp_contrib_individual_to_candidate.cycle=? AND crp_contrib_individual_to_candidate.recipient_osid=? AND
            crp_contrib_individual_to_candidate.contrib_type IN ('10', '11', '15 ', '15', '15E', '15J', '22Y')
      GROUP BY crp_industries.id)
        top_ind_is ON crp_industries.id=top_ind_is.id
    LEFT JOIN
      (SELECT crp_industries.id, SUM(crp_contrib_pac_to_candidate.amount) as pac_contrib_total
      FROM crp_industries
      INNER JOIN crp_interest_groups ON crp_industries.id=crp_interest_groups.crp_industry_id
      INNER JOIN crp_contrib_pac_to_candidate ON crp_interest_groups.osid=crp_contrib_pac_to_candidate.crp_interest_group_osid
      WHERE crp_contrib_pac_to_candidate.cycle=?
        AND crp_contrib_pac_to_candidate.recipient_osid=?
        AND crp_contrib_pac_to_candidate.contrib_type IN ('24K', '24R', '24Z')
      GROUP BY crp_industries.id)
        top_pac_is ON crp_industries.id=top_pac_is.id
    ORDER BY contrib_total DESC
    LIMIT ?", cycle, osid, cycle, osid, num])
  end

  def comments_from_state_count(state)
    ids = User.find_id_by_solr("my_state:\"#{state}\"", :facets => {:browse => ["my_state_f:\"#{state}\"", "my_people_tracked:#{self.id}"]}, :limit => 5000)
    comments_count = Comment.count(:id, :conditions => ["commentable_type = ? AND commentable_id = ? AND user_id in (?)", 'Person', self.id, ids.results])
    return comments_count
  end

  # sunlight api test, dont use
  def contact_link
    begin
      require 'open-uri'
      require 'hpricot'
      api_url = "http://www.api.sunlightlabs.com/people.getDataCondition.php?BioGuide_ID=#{bioguideid}&output=xml"
      response = Hpricot.XML(open(api_url))
      entry = (response/:entity_id).first.inner_html
      api_person_url = "http://api.sunlightlabs.com/people.getDataItem.php?id=#{entry}&code=webform&output=xml"
      person_response = Hpricot.XML(open(api_person_url))
      webform = (person_response/:webform).first.inner_html
      return webform
    catch Exception
      return false
    end
  end

  def office_zip
    senator? ? "20510" : "20515"
  end

  # expiring the cache
  def fragment_cache_key
    "person_#{id}"
  end

  def expire_govtrack_fragments
    fragments = []

    fragments << "#{fragment_cache_key}_header"

    FragmentCacheSweeper::expire_fragments(fragments)
  end

  def expire_opensecrets_fragments
    FragmentCacheSweeper::expire_fragments(["#{fragment_cache_key}_opensecrets"])
  end

  def expire_commentary_fragments(type)
    FragmentCacheSweeper::expire_commentary_fragments(self, type)
  end


  def set_party
     self.party = self.roles.first.party unless self.roles.empty?
  end

  def set_unaccented_name
    self.unaccented_name = I18n.transliterate(popular_name)
  end

  def obj_title
    self.title
  end

  def cleanup_commentaries
    deleted = 0
    commentaries = blogs + news

    commentaries.each_with_index do |c, i|
      #puts "Check commentary (#{i+1}/#{commentaries.size}): #{c.title} for #{self.name}"
      unless (c.title =~ /#{self.state}/ || c.excerpt =~ /#{self.state}/ ||
              c.title =~ /#{State.for_abbrev(self.state)}/i || c.excerpt =~ /#{State.for_abbrev(self.state)}/i)
        c.make_bad
        deleted += 1
      end
    end
    deleted
  end

  def formageddon_display_address
    addr = ""
    addr += "#{title_long} #{firstname} #{lastname}\n"
    addr += "#{congress_office}\n" unless congress_office.blank?
    addr += "Washington, DC #{office_zip}\n"
  end

  def as_json(ops = {})
    super(SERIALIZATION_OPS.merge(ops))
  end

  def as_xml(ops = {})
    super(SERIALIZATION_OPS.merge(ops))
  end

  def fec_ids
    person_identifiers.where(namespace: 'fec').map{|id| id.value}
  end

  def fec_ids=(ids=[])
    raise ArgumentError, "must pass in an array" unless ids.class == Array
    person_identifiers.where(namespace: 'fec').destroy_all #kill existing FEC ids
    ids.each do |id|
      person_identifiers.create!(
        namespace: 'fec',
        value: id
      )
    end
  end

  def add_fec_id(id)
    unless fec_ids.include?(id)
      person_identifiers.create!(
        namespace: 'fec',
        value: id
      )
    end
  end

end
