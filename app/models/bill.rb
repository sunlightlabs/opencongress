# == Schema Information
#
# Table name: bills
#
#  id                     :integer          not null, primary key
#  session                :integer
#  bill_type              :string(7)
#  number                 :integer
#  introduced             :integer
#  sponsor_id             :integer
#  lastaction             :integer
#  rolls                  :string(255)
#  last_vote_date         :integer
#  last_vote_where        :string(255)
#  last_vote_roll         :integer
#  last_speech            :integer
#  pl                     :string(255)
#  topresident_date       :integer
#  topresident_datetime   :date
#  summary                :text
#  plain_language_summary :text
#  hot_bill_category_id   :integer
#  updated                :datetime
#  page_views_count       :integer
#  is_frontpage_hot       :boolean
#  news_article_count     :integer          default(0)
#  blog_article_count     :integer          default(0)
#  caption                :text
#  key_vote_category_id   :integer
#  is_major               :boolean
#  top_subject_id         :integer
#  short_title            :text
#  popular_title          :text
#  official_title         :text
#  manual_title           :text
#

require_dependency 'viewable_object'
require_dependency 'united_states'
require_dependency 'wiki_connection'

class Bill < Bookmarkable

  # acts_as_solr :fields => [{:billtext_txt => :text},:bill_type,:session,{:title_short=>{:boost=>3}}, {:introduced => :integer}],
  #              :facets => [:bill_type, :session], :auto_commit => false

  #========== INCLUDES

  include ViewableObject

  #========== CALLBACKS

  before_save :update_bill_fulltext_search_table

  #========== CLASS VARIABLES

  @@DISPLAY_OBJECT_NAME = 'Bill'

  # Added these back in to make govtrack bill import work
  # to get the bill text that is marked up with the right paragraph ids
  @@TYPES = {
      'h' => 'H.R.',
      's' => 'S.',
      'hj' => 'H.J.Res.',
      'sj' => 'S.J.Res.',
      'hc' => 'H.Con.Res.',
      'sc' => 'S.Con.Res.',
      'hr' => 'H.Res.',
      'sr' => 'S.Res.'
  }

  @@TYPES_ORDERED = [ 's', 'sj',  'sc',  'sr', 'h', 'hj', 'hc', 'hr' ]

  @@GOVTRACK_TYPE_LOOKUP = {
      'hconres' => 'hc',
      'hjres' => 'hj',
      'hr' => 'h',
      'hres' => 'hr',
      's' => 's',
      'sconres' => 'sc',
      'sjres' => 'sj',
      'sres' => 'sr'
  }

  #========== CONSTANTS

  # different ways we may want to serialize json...
  SERIALIZATION_STYLES = {:simple => {:except => [:rolls, :hot_bill_category_id]},
                          :full => {:except => [:rolls, :hot_bill_category_id],
                                    :methods => [:title_full_common, :status],
                                    :include => {:co_sponsors => {:methods => [:oc_user_comments, :oc_users_tracking]},
                                                 :sponsor => {:methods => [:oc_user_comments, :oc_users_tracking]},
                                                 :bill_titles => {},
                                                 :most_recent_actions => {}
                                    }}}

  #========== CALLBACKS

  after_save -> { @bill_text = nil }

  #========== RELATIONS

  #----- HAS_ONE

  has_one :sidebar_box, :as => :sidebarable
  has_one :bill_stats
  has_one :bill_fulltext
  has_one :wiki_link, :as => "wikiable"
  has_one  :last_action, -> { order('actions.date DESC') },
           :class_name => "Action"
  has_one  :related_bill_session, -> { order("bills_relations.relation='session'") },
           :through => :bill_relations, :source => :related_bill

  #----- HAS_MANY

  has_many :bill_titles
  has_many :bill_cosponsors
  has_many :co_sponsors, -> { order('lastname') },
           :through => :bill_cosponsors, :source => :person
  has_many :actions, -> { order('ordinal_position DESC') },
           :class_name => 'BillAction'
  has_many :bill_committees
  has_many :committees,
           :through => :bill_committees
  has_many :bill_relations
  has_many :related_bills,
           :through => :bill_relations, :source => :related_bill
  has_many :bill_subjects
  has_many :subjects,
           :through => :bill_subjects
  has_many :amendments, -> { includes(:roll_calls).order(["offered_datetime DESC", "number DESC"]) }
  has_many :roll_calls, -> { order('date DESC') }
  has_many :comments,
           :as => :commentable
  has_many :object_aggregates,
           :as => :aggregatable
  has_many :bill_referrers
  has_many :bill_votes
  has_many :most_recent_actions, -> { order('actions.date DESC').limit(5) },
           :class_name => "Action"
  has_many :talking_points,
           :as => :talking_pointable
  has_many :bill_text_versions
  has_many :videos, -> { order("videos.video_date DESC, videos.id") }
  has_many :notebook_links,
           :as => :notebookable
  has_many :committee_meetings_bills
  has_many :committee_meetings,
           :through => :committee_meetings_bills
  has_many :committee_reports
  has_many :friend_emails, -> { order('created_at') },
           :as => :emailable
  has_many :bill_interest_groups, -> { includes(:crp_interest_group).order('crp_interest_groups.order') },
           :dependent => :destroy
  has_many :bill_position_organizations,
           :dependent => :destroy
  has_many :contact_congress_letters,
           :as => :contactable

  with_options :class_name => 'Commentary' do |c|
    c.has_many :news, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='t'").order('commentaries.date DESC, commentaries.id DESC') },
               :as => :commentariable
    c.has_many :blogs,-> { where("commentaries.is_ok = 't' AND commentaries.is_news='f'").order('commentaries.date DESC, commentaries.id DESC') },
               :as => :commentariable
  end

  #----- BELONGS_TO

  belongs_to :sponsor,
             :class_name => 'Person', :foreign_key => :sponsor_id
  belongs_to :top_subject,
             :class_name => 'Subject', :foreign_key => :top_subject_id
  belongs_to :hot_bill_category,
             :class_name => "PvsCategory", :foreign_key => :hot_bill_category_id
  belongs_to :key_vote_category,
             :class_name => "PvsCategory", :foreign_key => :key_vote_category_id

  #========== ALIASES

  alias :blog :blogs

  #========== ACCESSORS

  attr_accessor :search_relevancy
  attr_accessor :tmp_search_desc
  attr_accessor :wiki_summary_holder

  #========== SCOPES

  scope :for_subject, lambda {|subj| includes(:subjects).where("subjects.term" => subj)}
  scope :major, where(:is_major => true)
  scope :recently_acted, joins(:bill_titles, :actions).order("actions.date DESC")
  scope :for_session, lambda {|sess| where("bills.session = ?", sess)}
  scope :senate_bills, where(:bill_type => (@@GOVTRACK_TYPE_LOOKUP.keys.keep_if{|k| k[0] == 's'}))
  scope :house_bills, where(:bill_type => (@@GOVTRACK_TYPE_LOOKUP.keys.keep_if{|k| k[0] == 'h'}))

  #========== INSTANCE METHODS

  def reverse_abbrev_lookup
    return @@GOVTRACK_TYPE_LOOKUP[self.bill_type]
  end

  #========== CLASS METHODS

  # This can also be removed when we completely get rid of GovTrack
  def self.get_types_ordered
    return @@TYPES_ORDERED
  end

  def self.get_types_ordered_new
    return UnitedStates::Bills::ABBREVIATIONS
  end

  class << self

    def govtrack_reverse_lookup (typename)
      return @@GOVTRACK_TYPE_LOOKUP.invert[typename]
    end

    def govtrack_lookup (typename)
      return @@GOVTRACK_TYPE_LOOKUP[typename]
    end

    def available_sessions(relation = Bill.all)
      relation.select("DISTINCT session").map(&:session).uniq.sort
    end

    def all_types
      UnitedStates::Bills::ABBREVIATIONS
    end

    def all_types_ordered
      sorted_pairs = UnitedStates::Bills::ABBREVIATIONS.sort_by do |k, v|
        v.length
      end
      Hash[sorted_pairs].keys
    end

    def in_senate
      UnitedStates::Bills::ABBREVIATIONS.keys[4..7]
    end

    def in_house
      UnitedStates::Bills::ABBREVIATIONS.keys[0..3]
    end
  end

  def bill_id
    "#{bill_type}#{number}-#{session}"
  end

  def update_bill_fulltext_search_table
    if self.id
      # when the bill is new, the bill titles will have just been added to the DB.
      # using raw sql is the only way i've found to get them (the 'force_reload'
      # option on the association does not seem to work.)  if there is a better way
      # if should be implemented
      bts = BillTitle.find_by_sql(["SELECT bill_titles.* FROM bill_titles WHERE bill_id=?", id])

      self.build_bill_fulltext if self.bill_fulltext.nil?
      self.bill_fulltext.fulltext = "#{bill_type}#{number} #{bill_type} #{number} #{type_name}#{number} #{type_name} #{bts.collect(&:title).join(" ")} #{plain_language_summary}"
      self.bill_fulltext.save

      # also, set the lastaction field unless it's a brand new record
      self.lastaction = last_action.date if last_action
    end
  end

  def display_object_name
    @@DISPLAY_OBJECT_NAME
  end

  def organizations_supporting
    bill_position_organizations.all.select{ |g| g.disposition == 'support' }
  end

  def organizations_opposing
    bill_position_organizations.all.select{ |g| g.disposition == 'oppose' }
  end

  def current_bill_text_version
    versions = bill_text_versions.where('bill_text_versions.previous_version IS NULL')#(find(:all, :conditions => "bill_text_versions.previous_version IS NULL")
    if versions.empty?
      return nil
    end

    v = bill_text_versions.where('bill_text_versions.previous_version=?', versions.first.version).first()#find(:first, :conditions => ["bill_text_versions.previous_version=?", versions.first.version])
    until v.nil?
      versions << v
      v = bill_text_versions.where('bill_text_versions.previous_version=?', v.version).first()
    end

    versions.last
  end

  def current_cosponsor_count
    bill_cosponsors.where("bills_cosponsors.date_withdrawn IS NULL").size
  end

  def top_rated_news_items
     ids = CommentaryRating.count(:id, :group => "commentaries.id",
                            :include => "commentary",
                            :conditions => ["commentaries.commentariable_id = ? AND commentaries.commenariable_type='Bill' AND commentaries.is_news = ?", self.id, true], :order => "count_id DESC").collect {|p| p[1] > 1 ? p[0] : nil }.compact
     coms = CommentaryRating.calculate(:avg, :rating,
                                       :include => "commentary", :conditions => ["commentary_id in (?)", ids],
                                       :group => "commentaries.id", :order => "avg_rating DESC")
  end

  def top_rated_blog_items
     ids = CommentaryRating.count(:id, :group => "commentaries.id",
                            :include => "commentary",
                            :conditions => ["commentaries.commentariable_id = ? AND commentaries.commenariable_type='Bill' AND commentaries.is_news = ?", self.id, false], :order => "count_id DESC").collect {|p| p[1] > 1 ? p[0] : nil }.compact
     coms = CommentaryRating.calculate(:avg, :rating,
                                       :include => "commentary", :conditions => ["commentary_id in (?)", ids],
                                       :group => "commentaries.id", :order => "avg_rating DESC")
  end

  def Bill.find_with_most_commentary_ratings
    ids = CommentaryRating.count(:id, :group => "commentaries.commentariable_id", :include => "commentary", :conditions => "commentaries.commentariable_type='Bill'", :order => "count_id DESC").collect {|p| p[0]}
    where(id:ids)
  end

  def is_house_bill?
    bill_type.include? "h"
  end

  def is_senate_bill?
    bill_type.include? "s"
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
      # check for the link in the wiki DB
      wiki_link = Wiki.wiki_link_for_bill(self.session, "#{self.bill_type.upcase}#{self.number}")
      unless wiki_link.blank?
        WikiLink.create(:wikiable => self, :name => wiki_link, :oc_link => "#{Settings.base_url}/bill/#{self.ident}/show")
        link = "#{Settings.wiki.base_url}/#{wiki_link}"
      else
        link = ""
      end
    else
      link = "#{Settings.wiki_base_url}/#{self.wiki_link.name}"
    end

    return link

  end

  def wiki_summary
    w = nil
    if self.wiki_summary_holder.nil? and !self.wiki_link.blank?
      w = Wiki.summary_text_for(self.wiki_link.name)
      if w.blank?
        wiki_summary_holder = ''
      else
        wiki_summary_holder = w
      end
    end

    return wiki_summary_holder
  end

  def text_comments_count
    Bill.count_by_sql(["SELECT count(*) FROM bill_text_versions INNER JOIN bill_text_nodes ON bill_text_nodes.bill_text_version_id=bill_text_versions.id
                  INNER JOIN comments ON comments.commentable_id=bill_text_nodes.id
                  WHERE bill_text_versions.bill_id=? AND comments.commentable_type='BillTextNode'", self.id])
  end

  def recent_activity(since = nil)
    items = []
    actions.find(:all, :conditions => ["created_at >= ?", since], :order => "datetime desc")
    items = actions
    items
  end

  def recent_activity_mini_list(since = nil)
    host = URI.parse(Settings.base_url).host

    items = []
    self.recent_activity(since).each do |i|
        items << {:sort_date => i.datetime.to_date, :content => i.to_s, :link => {:host => host, :only_path => false, :controller => 'bill', :action => 'show', :id => self.ident}}
    end
    items.group_by{|x| x[:sort_date]}.to_a.sort{|a,b| b[0]<=>a[0]}
  end

  def support_suggestions
    [0, {}]
  end

  def oppose_suggestions
    [0, {}]
  end

  # Returns the number of people tracking this bill, as well as suggestions of what other people
  # tracking this bill are also tracking.
  def tracking_suggestions
    # temporarily removing solr for now - June 2012
    return [0, {}]

    facet_results_hsh = {:my_people_tracked_facet => [], :my_issues_tracked_facet => [], :my_bills_tracked_facet => []}
    my_trackers = 0

    begin
      users = User.find_by_solr('placeholder:placeholder', :facets => {:fields => [:my_people_tracked, :my_issues_tracked, :my_bills_tracked],
                                                        :browse => ["my_bills_tracked:#{self.ident}"],
                                                        :limit => 6, :zeros => false, :sort =>  true}, :limit => 1)
      facets = users.facets
    rescue
      return [0, {}] unless Rails.env == 'production'
      raise
    end



    facet_results_ff = facets['facet_fields']
    if facet_results_ff && facet_results_ff != []

      facet_results_ff.each do |fkey, fvalue|
        facet_results = facet_results_ff[fkey]

        #solr running through acts as returns as a Hash, or an array if running through tomcat...hence this stuffs
        facet_results_temp_hash = Hash[*facet_results] unless facet_results.class.to_s == "Hash"
        facet_results_temp_hash = facet_results if facet_results.class.to_s == "Hash"

        facet_results_temp_hash.each do |key,value|
          if key == self.ident.to_s && fkey == "my_bills_tracked_facet"
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

  def to_light_xml(options = {})
    default_options = {:except => [:rolls, :hot_bill_category_id, :summary, :fti_titles,:bookmark_count_2,
                                   :fti_names,:current_support_pb, :support_count_1, :rolls, :hot_bill_category_id,
                                   :support_count_2, :vote_count_2],
                                :methods => [:title_full_common, :status, :ident]
                                }
    self.to_xml(default_options.merge(options))
  end

  def to_medium_xml(options = {})
    default_options = {:except => [:rolls, :hot_bill_category_id, :summary, :fti_titles],
                                :methods => [:title_full_common, :status, :ident],
                                :include => {:co_sponsors => {:methods => [:oc_user_comments, :oc_users_tracking]},
                                             :sponsor => {:methods => [:oc_user_comments, :oc_users_tracking]},
                                             :bill_titles => {},
                                             :most_recent_actions => {}
                                             }
                                }
    self.to_xml(default_options.merge(options))
  end

  class << self
    # return bill actions since last X
    def find_changes_since_for_bills_tracked(current_user)
       time_since = current_user.previous_login_date || 20.days.ago
       time_since = 200.days.ago if Rails.env.development?
       ids = current_user.bill_bookmarks.collect{|p| p.bookmarkable_id}
       find_by_sql(["select bills.*, total_actions.action_count as actionn_count,
                        total_blogs.blog_count as blogss_count, total_news.news_count as newss_count,
                        total_comments.comments_count as commentss_count from bills
                    LEFT OUTER JOIN (select count(actions.id) as action_count,
                        actions.bill_id as bill_id_1 FROM actions WHERE
                        actions.datetime > '#{time_since.to_s(:db)}'
                        AND actions.bill_id in (#{ids.join(",")})
                        group by bill_id_1) total_actions ON
                        total_actions.bill_id_1 = bills.id
                    LEFT OUTER JOIN (select count(commentaries.id) as blog_count,
                        commentaries.commentariable_id as bill_id_2 FROM commentaries WHERE
                        commentaries.commentariable_id IN (#{ids.join(",")}) AND
                        commentaries.commentariable_type='Bill' AND
                        commentaries.is_ok = 't' AND commentaries.is_news='f' AND
                        commentaries.date > '#{time_since.to_s(:db)}'
                        group by commentaries.commentariable_id)
                        total_blogs ON total_blogs.bill_id_2 = bills.id
                    LEFT OUTER JOIN (select count(commentaries.id) as news_count,
                        commentaries.commentariable_id as bill_id_3 FROM commentaries WHERE
                        commentaries.commentariable_id IN (#{ids.join(",")}) AND
                        commentaries.commentariable_type='Bill' AND
                        commentaries.is_ok = 't' AND commentaries.is_news='t' AND
                        commentaries.date > '#{time_since.to_s(:db)}'
                        group by commentaries.commentariable_id)
                        total_news ON total_news.bill_id_3 = bills.id
                    LEFT OUTER JOIN (select count(comments.id) as comments_count,
                        comments.commentable_id as bill_id_4 FROM comments WHERE
                        comments.created_at > '#{time_since.to_s(:db)}' AND
                        comments.commentable_id in (#{ids.join(",")}) AND
                        comments.commentable_type = 'Bill' GROUP BY comments.commentable_id)
                        total_comments ON total_comments.bill_id_4 = bills.id WHERE bills.id IN (?)", current_user.bill_bookmarks.collect{|p| p.bookmarkable_id}])
    end

    # return bill actions since last X
    def find_user_data_for_tracked_bill(bill, current_user)
       time_since = current_user.previous_login_date || 20.days.ago
       time_since = 200.days.ago if Rails.env.development?
       find_by_id(bill.id,
                      :select => "bills.*, (select count(actions.id) from actions where actions.datetime > '#{time_since.to_s(:db)}' AND bill_id = #{bill.id} ) as action_count,
                          (select count(commentaries.id) FROM commentaries
                               WHERE commentaries.commentariable_id = #{bill.id}
                                 AND commentaries.commentariable_type='Bill'
                                 AND commentaries.is_ok = 't'
                                 AND commentaries.is_news='f'
                                 AND commentaries.date > '#{time_since.to_s(:db)}') as blog_count,
                          (select count(commentaries.id) FROM commentaries
                               WHERE commentaries.commentariable_id = #{bill.id}
                                  AND commentaries.commentariable_type='Bill'
                                  AND commentaries.is_ok = 't'
                                  AND commentaries.is_news='t'
                                  AND commentaries.date > '#{time_since.to_s(:db)}') as newss_count,
                          (select count(comments.id) FROM comments
                               WHERE comments.created_at > '#{time_since.to_s(:db)}'
                                 AND comments.commentable_type='Bill'
                                 AND comments.commentable_id = #{bill.id}) as comment_count")
    end

    def find_all_by_most_user_votes_for_range(range, options)
      range = 30.days.to_i if range.nil?
      possible_orders = ["vote_count_1 desc", "vote_count_1 asc", "current_support_pb asc",
                         "current_support_pb desc", "bookmark_count_1 asc", "bookmark_count_1 desc",
                         "support_count_1 desc", "support_count_1 asc", "total_comments asc", "total_comments desc"]
      order = options[:order] ||= "vote_count_1 desc"
      search = options[:search]
      if possible_orders.include?(order)

        limit = options[:limit] ||= 20
        offset = options[:offset] ||= 0
        not_null_check = order.split(' ').first

        query = "
            SELECT
              bills.*,
              #{search ? "rank(bill_fulltext.fti_names, ?, 1) as tsearch_rank, " : "" }
              current_period.vote_count_1 as vote_count_1,
              current_period.support_count_1 as support_count_1,
              (total_counted.total_count - total_supported.total_support) as total_support,
              current_period.current_support_pb as current_support_pb,
              comments_total.total_comments as total_comments,
              current_period_book.bookmark_count_1 as bookmark_count_1,
              previous_period.vote_count_2 as vote_count_2,
              previous_period.support_count_2 as support_count_2,
              total_supported.total_support as total_opposed,
              total_counted.total_count as total_count
            FROM
              #{search ? "bill_fulltext," : ""}
              bills
            INNER JOIN (
              select bill_votes.bill_id  as bill_id_1,
              count(bill_votes.bill_id) as vote_count_1,
              sum(bill_votes.support) as support_count_1,
              (count(bill_votes.bill_id) - sum(bill_votes.support)) as current_support_pb
              FROM bill_votes
              WHERE created_at > ? group by bill_id_1)
            current_period ON bills.id = current_period.bill_id_1
            LEFT OUTER JOIN (
              select bill_votes.bill_id as bill_id_3,
              sum(bill_votes.support) as total_support
              FROM bill_votes
              GROUP BY bill_votes.bill_id)
            total_supported ON bills.id = total_supported.bill_id_3
            LEFT OUTER JOIN (
              select bill_votes.bill_id as bill_id_4,
              count(bill_votes.support) as total_count
              FROM bill_votes
              GROUP BY bill_votes.bill_id)
            total_counted ON bills.id = total_counted.bill_id_4
            LEFT OUTER JOIN (
              select comments.commentable_id as bill_id_5,
              count(comments.id) as total_comments
              FROM comments
              WHERE created_at > ? AND
              comments.commentable_type = 'Bill'
              GROUP BY comments.commentable_id)
            comments_total ON bills.id = comments_total.bill_id_5
            LEFT OUTER JOIN (
              select bill_votes.bill_id as bill_id_2,
              count(bill_votes.bill_id) as vote_count_2,
              sum(bill_votes.support) as support_count_2
              FROM bill_votes
              WHERE created_at > ? AND
              created_at <= ?
              GROUP BY bill_id_2)
            previous_period ON bills.id = previous_period.bill_id_2
            LEFT OUTER JOIN (
              select bookmarks.bookmarkable_id as bill_id_1,
               count(bookmarks.bookmarkable_id) as bookmark_count_1
               FROM bookmarks
                   WHERE created_at > ?
               GROUP BY bill_id_1)
            current_period_book ON bills.id = current_period_book.bill_id_1
            WHERE #{not_null_check} IS NOT NULL
            #{search ? "AND bill_fulltext.fti_names @@ to_tsquery('english', ?)
            AND bills.id = bill_fulltext.bill_id" : ""}
            ORDER BY #{order}
            LIMIT #{limit}"

        query_params = [range.seconds.ago,range.seconds.ago, (range*2).seconds.ago, range.seconds.ago, range.seconds.ago]

        if search
          # Plug the search parameters into the query parmaeters
          query_params.unshift(search)
          query_params.push(search)
        end

        Bill.find_by_sql([query, *query_params])
      else
        return []
      end
    end

    def count_all_by_most_user_votes_for_range(range, options)
      possible_orders = ["vote_count_1 desc", "vote_count_1 asc", "current_support_pb asc",
                         "current_support_pb desc", "bookmark_count_1 asc", "bookmark_count_1 desc",
                         "support_count_1 desc", "support_count_1 asc", "total_comments asc", "total_comments desc"]
      order = options[:order] ||= "vote_count_1 desc"
      search = options[:search]
      if possible_orders.include?(order)
        join_query = ""
        join_query_bind = []
        case order.split.first
          when "bookmark_count_1"
            join_query = "INNER JOIN (select bookmarks.bookmarkable_id as bill_id
                   FROM bookmarks
                  WHERE created_at > ? GROUP BY bookmarkable_id)
               current_period_book ON bills.id=current_period_book.bill_id"
            join_query_bind = [range.seconds.ago]
          when "total_comments"
            join_query = "INNER JOIN (select comments.commentable_id as bill_id
                FROM comments
                   WHERE created_at > ? AND
                         comments.commentable_type = 'Bill'
                GROUP BY comments.commentable_id)
            comments_total ON bills.id=comments_total.bill_id"
            join_query_bind = [range.seconds.ago]
        end

        query = "SELECT count(bills.*)
            FROM
              #{search ? "bill_fulltext," : ""}
              bills
             INNER JOIN (select bill_votes.bill_id
                 FROM bill_votes WHERE created_at > ?
                 GROUP BY bill_votes.bill_id) current_period
             ON bills.id = current_period.bill_id
             #{join_query}
            #{search ? "WHERE bill_fulltext.fti_names @@ to_tsquery('english', ?) AND bills.id = bill_fulltext.bill_id" : ""}"
        query_params = [range.seconds.ago, *join_query_bind]

        if search
          query_params.push(search)
        end

        k = Bill.count_by_sql([query, *query_params])
        return k
      else
        return []
      end
    end

    # Why are these next two methods in Bill if they just return BillVote stuff?
    def total_votes_last_period(minutes)
      return BillVote.calculate(:count, :all, :conditions => {:created_at => (Time.new - (minutes*2))..(Time.new - (minutes))})
    end

    def total_votes_this_period(minutes)
      return BillVote.calculate(:count, :all, :conditions => ["created_at > ?", Time.new - (minutes)])
    end

    def percentage_difference_in_periods(minutes)
      return (Bill.total_votes_last_period(minutes).to_f) / Bill.total_votes_this_period(minutes).to_f
    end

  end # << self

  def adjusted_votes_this_period(total,this_period,minutes)
    return this_period.to_f * total.to_f
  end

  def is_vote_hot?(total,previous_period,this_period,minutes)
    ajvtp = self.adjusted_votes_this_period(total,this_period,minutes)
    return true if ( ajvtp > 3 && ( (ajvtp  / 6) > previous_period ) )
  end

  def is_vote_cold?(total,previous_period,this_period,minutes)
    ajvtp = self.adjusted_votes_this_period(total,this_period,minutes)
    return true if ( ajvtp > 3 && ( ajvtp < ( previous_period / 1.01) ) )
  end

  def chamber
    if bill_type.starts_with? "h"
      "house"
    else
      "senate"
    end
  end

  def other_chamber
    if bill_type.starts_with? "h"
      "senate"
    else
      "house"
    end
  end

  class << self
    def find_by_ident(ident_string, find_options = {})
      bill_type, number, session = Bill.ident ident_string
      Bill.find_by_session_and_bill_type_and_number(session, bill_type, number, find_options)
    end

    def find_all_by_ident(ident_array, find_options = {})
      the_bill_conditions = []
      the_bill_params = {}
      limit = find_options[:limit] != 20
      round = 1
      ident_array.each do |ia|
        bill_type, number, session = Bill.ident ia
        the_bill_conditions << "(session = :session#{round} AND bill_type = :bill_type#{round} AND number = :number#{round})"
        the_bill_params.merge!({"session#{round}".to_sym => session, "bill_type#{round}".to_sym => bill_type, "number#{round}".to_sym => number})
        round = round + 1
      end
      Bill.find(:all, :conditions => ["#{the_bill_conditions.join(' OR ')}", the_bill_params], :limit => find_options[:limit])
  #    Bill.find_by_session_and_bill_type_and_number(session, bill_type, number, find_options)
    end

    def long_type_to_short(type)
      raise RuntimeError, "long_type_to_short must be killed!"
    end

    def session_from_date(date)
      session_a = OpenCongress::Application::CONGRESS_START_DATES.to_a.sort { |a, b| a[0] <=> b[0] }

      session_a.each_with_index do |s, i|
        return nil if s == session_a.last
        s_date = Date.parse(s[1])
        e_date = Date.parse(session_a[i+1][1])

        if date >= s_date and date < e_date
          return s[0]
        end
      end
      return nil
    end

    def top20_viewed
      bills = ObjectAggregate.popular('Bill')

      (bills.select {|b| b.stats.entered_top_viewed.nil? }).each do |bv|
        bv.stats.entered_top_viewed = Time.now
        bv.save
      end

      (bills.sort { |b1, b2| b2.stats.entered_top_viewed <=> b1.stats.entered_top_viewed })
    end

    def top5_viewed
      bills = ObjectAggregate.popular('Bill', Settings.default_count_time, 5)

      (bills.select {|b| b.stats.entered_top_viewed.nil? }).each do |bv|
        bv.stats.entered_top_viewed = Time.now
        bv.save
      end

      (bills.sort { |b1, b2| b2.stats.entered_top_viewed <=> b1.stats.entered_top_viewed })
    end

    def top20_commentary(type = 'news')
      bills = Bill.find_by_most_commentary(type, num = 20)

      date_method = :"entered_top_#{type}"
      (bills.select {|b| b.stats.send(date_method).nil? }).each do |bv|
        bv.stats.send("#{date_method}=", Time.now)
        bv.save
      end

      (bills.sort { |b1, b2| b2.stats.send(date_method) <=> b1.stats.send(date_method) })
    end

    def random(limit)
      Bill.find_by_sql ["SELECT * FROM (SELECT random(), bills.* FROM bills ORDER BY 1) as bs LIMIT ?;", limit]
    end
  end # class << self

  def log_referrer(referrer)
    unless (referrer.blank? || BillReferrer.no_follow?(referrer))
      self.bill_referrers.find_or_create_by(url:referrer[0..253])
    end
  end

  def unique_referrers(since = 2.days)
    ref_views = PageView.find(:all,
                              :select => "DISTINCT(page_views.referrer)",
                              :conditions => ["page_views.referrer IS NOT NULL AND
                                               page_views.viewable_id = ? AND
                                               page_views.viewable_type = 'Bill' AND
                                               page_views.created_at > ?", id, since.ago])
    ref_views.collect { |v| v.referrer }
  end

  def related_articles
    Article.tagged_with(subject_terms, :any => true).order('created_at DESC').limit(5)
  end

  def subject_categories
    subjects.where('parent_id is not null').select{ |s| s.parent_id == Subject.root_category.id }
  end

  def subject_terms
    subjects.collect{|s| s.term }
  end

  def subject
    #most popular subject that is not in the top X
    num = 8

    if subjects.empty?
      Subject.find_by_term("Congress")
    else
      @top ||= Subject.order("bill_count desc").limit(num)
      subjects.sort_by { |b| b.bill_count }.reverse.find { |s| ! @top.include?(s) }
    end
  end

  def commentary_count(type = 'news', since = Settings.default_count_time)
    return @attributes['article_count'] if @attributes['article_count']

    if type == 'news'
      self.news.find(:all, :conditions => [ "commentaries.date > ?", since.ago]).size
    else
      self.blogs.find(:all, :conditions => [ "commentaries.date > ?", since.ago]).size
    end
  end

  def stats
    self.build_bill_stats unless self.bill_stats
    self.bill_stats
  end

  # returns a float between 0 and 1 corresponding to the percentage of it's blog and news
  # articles that are less than a week old
  def commentary_freshness
    total_news = self.news.size
    total_blogs = self.blogs.size
    if (total_news + total_blogs) > 0
      fresh_news = self.news.select { |n| n.date > Settings.default_count_time.ago }
      fresh_blogs = self.blogs.select { |b| b.date > Settings.default_count_time.ago }
      return ((fresh_news.size.to_f + fresh_blogs.size.to_f) / (total_news.to_f + total_blogs.to_f))
    else
      return 0
    end
  end

  # returns a float between 0 and 1 corresponding to the percentage of it's actions
  # that are less than a month old
  def activity_freshness
    actions.size ? ((actions.select { |a| a.datetime > 30.days.ago}).size.to_f / actions.size.to_f ) : 0
  end

  class << self
    def sponsor_count
      Bill.count(:all, :conditions => ["session = ?", Settings.default_congress], :group => "sponsor_id").sort {|a,b| b[1]<=>a[1]}
    end

    def cosponsor_count
      Bill.count(:all, :include => [:bill_cosponsors], :conditions => ["bills.session = ?", Settings.default_congress], :group => "bills_cosponsors.person_id").sort {|a,b| b[1]<=>a[1]}
    end

    def find_by_most_commentary(type = 'news', num = 5, since = Settings.default_count_time, congress = Settings.default_congress, bill_types = ["h", "hc", "hj", "hr", "s", "sc", "sj", "sr"])

      is_news = (type == "news") ? true : false

      Bill.find_by_sql(["SELECT bills.*, top_bills.article_count AS article_count FROM bills
                         INNER JOIN
                         (SELECT commentaries.commentariable_id, count(commentaries.commentariable_id) AS article_count
                          FROM commentaries
                          WHERE commentaries.commentariable_type='Bill' AND
                                commentaries.date > ? AND
                                commentaries.is_news=? AND
                                commentaries.is_ok='t'
                          GROUP BY commentaries.commentariable_id
                          ORDER BY article_count DESC) top_bills
                         ON bills.id=top_bills.commentariable_id
                         WHERE bills.session = ? AND bills.bill_type IN (?)
                         ORDER BY article_count DESC LIMIT ?",
                        since.ago, is_news, congress, bill_types, num])
    end

    def find_stalled_in_second_chamber(original_chamber = 's', session = Settings.default_congress, num = :all)
      Bill.find_by_sql(["SELECT bills.* FROM bills
                          INNER JOIN actions a_v ON (bills.id=a_v.bill_id AND a_v.vote_type='vote' AND a_v.result='pass')
                        WHERE bills.bill_type=? AND bills.session=?
                        EXCEPT
                          (SELECT bills.* FROM bills
                            INNER JOIN actions a_v ON (bills.id=a_v.bill_id AND a_v.vote_type='vote' AND a_v.result='pass')
                            INNER JOIN actions a_v2 ON (bills.id=a_v2.bill_id AND (a_v2.vote_type='vote2' OR a_v2.vote_type='conference'))
                            WHERE bills.bill_type=? AND bills.session=?);", original_chamber, session, original_chamber, session])
    end
  end

  def top_recipients_for_all_interest_groups(disposition = 'support', chamber = 'house', num = 10)

    groups = self.bill_interest_groups.select{|g| g.disposition == disposition}
    groups_ids = groups.collect { |g| g.crp_interest_group.osid }

    title = (chamber == 'house') ? 'Rep.' : 'Sen.'
    Person.find_by_sql(["SELECT people.*, top_recips_ind.ind_contrib_total, top_recips_pac.pac_contrib_total, (COALESCE(top_recips_ind.ind_contrib_total, 0) + COALESCE(top_recips_pac.pac_contrib_total, 0)) AS contrib_total FROM people
      LEFT JOIN
        (SELECT recipient_osid, SUM(crp_contrib_individual_to_candidate.amount) as ind_contrib_total
         FROM crp_contrib_individual_to_candidate
         WHERE crp_interest_group_osid IN (?)
           AND cycle=?
           AND crp_contrib_individual_to_candidate.contrib_type IN ('10', '11', '15 ', '15', '15E', '15J', '22Y')
         GROUP BY recipient_osid)
        top_recips_ind ON people.osid=top_recips_ind.recipient_osid
      LEFT JOIN
        (SELECT recipient_osid, SUM(crp_contrib_pac_to_candidate.amount) as pac_contrib_total
         FROM crp_contrib_pac_to_candidate
         WHERE crp_contrib_pac_to_candidate.crp_interest_group_osid IN (?)
           AND crp_contrib_pac_to_candidate.cycle=?
           AND contrib_type IN ('24K', '24R', '24Z')
         GROUP BY crp_contrib_pac_to_candidate.recipient_osid)
        top_recips_pac ON people.osid=top_recips_pac.recipient_osid
     WHERE people.title=?
     ORDER BY contrib_total DESC
     LIMIT ?", groups_ids, Settings.current_opensecrets_cycle, groups_ids, Settings.current_opensecrets_cycle, title, num])
  end

  def bill_position_organizations_support
    bill_position_organizations.where("bill_position_organizations.disposition='support'")
  end
  def bill_position_organizations_oppose
    bill_position_organizations.where("bill_position_organizations.disposition='oppose'")
  end
  def relevant_industries
    unless self.hot_bill_category.nil?
      return self.hot_bill_category.crp_industries
    else
      ind = []
      self.subjects.each { |s|
        ind.concat(s.pvs_categories.collect{ |c| c.crp_industries })
      }

      return ind.flatten.uniq
    end
  end

  class << self
    def client_id_to_url(client_id)
      client_id.slice!(/\d+_/)
      long_type_to_short(client_id)
    end

    def from_param(param)
      md = /^(\d+)_(hconres|hres|hr|hjres|sjres|sconres|s|sres)(\d+)$/.match(param)
      return [nil, nil, nil] unless md
      id = md.captures[0].to_i
      t = Bill.long_type_to_short(md.captures[1])
      num = md.captures[2].to_i
      (id || t | num) ? [id, t, num] : [nil, nil, nil]
    end

    def canonical_name(name)
      "#{name.gsub(/[\.\s\/]+/,"").downcase}"
    end

    def ident(bill_id)
      pattern = /(hconres|hjres|hr|hres|s|sconres|sjres|sres)(\d+)-(\d+)/i
      match = pattern.match(bill_id)
      if match
        [match.captures[0].downcase,
         match.captures[1],
         match.captures[2]]
      else
        pattern = /(\d+)-(hc|hj|h|hr|s|sc|sj|sr)(\d+)/i
        match = pattern.match(bill_id)
        if match
          [Bill.govtrack_reverse_lookup(match.captures[1].downcase),
           match.captures[2],
           match.captures[0]]
        else
          [nil, nil, nil]
        end
      end
    end

    def ident_pattern
      /((\d+-[hs][rjc]?\d+)|((hconres|hjres|hres|hr|sconres|sjres|sres|s)\d+-\d+))/
    end
  end # class << self

  def ident
    "#{bill_type}#{number}-#{session}"
  end

  def to_param
    self.ident
  end

  def atom_id_as_feed
    "tag:opencongress.org,#{Time.at(introduced).strftime("%Y-%m-%d")}:/bill_feed/#{ident}"
  end

  def atom_id_as_entry
    "tag:opencongress.org,#{Time.at(introduced).strftime("%Y-%m-%d")}:/bill/#{ident}"
  end

  def atom_id_as_entry_with_action
    "tag:opencongress.org,#{Time.at(introduced).strftime("%Y-%m-%d")}:/bill/#{ident}/last_action"
  end

  # used when sorting with other types of objects
  def sort_date
    Time.at(self.introduced)
  end

  def rss_date
    Time.at(self.introduced)
  end

  def last_action_at
    Time.at(self.lastaction) if self.lastaction
  end

  def introduced_at
    Time.at(self.introduced) if self.introduced
  end

  def last_5_actions
    actions.find(:all, :order => "date DESC", :limit => 5)
  end

  def status(options = {})
    status_hash = self.bill_status_hash
    return status_hash['steps'][status_hash['current_step']]['text']
  end

  def status_class
    status_hash = self.bill_status_hash
    return status_hash['steps'][status_hash['current_step']]['class']
  end


  def next_step
    status_hash = self.bill_status_hash
    return status_hash['steps'][status_hash['current_step'] + 1] ?
           status_hash['steps'][status_hash['current_step'] + 1]['text'] : nil
  end

  def hours_to_first_attempt_to_pass
    (originating_chamber_vote.datetime - introduced_at) / 3600
  end

  ## bill title methods

  def type_name
    UnitedStates::Bills.abbreviation_for bill_type
  end

  def title_short
    title = short_title
    title ? "#{title.title}" : "#{type_name}#{number}"
  end

  def typenumber # just the type and number, ie H.R.1591
    "#{type_name}#{number}"
  end

  def title_official # just the official title
    official_title ? "#{official_title.title}" : ""
  end

  def title_popular_only # popular or short, returns empty string if one doesn't exist
    title = default_title || popular_title || short_title

    title ? "#{title.title}" : ""
  end

  def title_common # popular or short or official, returns empty string if one doesn't exist
    title = default_title || popular_title || short_title || official_title

    title ? "#{title.title}" : ""
  end

  def title_full_common # bill type, number and popular, short or official title
    title = default_title || popular_title || short_title || official_title

    if title.nil?
      ""
    else
      "#{title_prefix} #{number}: #{title.title}"
    end
  end

  def title_prefix
    prefix = UnitedStates::Bills.abbreviation_for bill_type
  end

  def title_for_share
    typenumber
  end

  # methods for progress
  def introduced_action
    actions.select { |a| a.action_type == 'introduced' }.first
  end

  def originating_chamber_vote
    actions.select { |a| (a.action_type == 'vote' and a.vote_type == 'vote') }.last
  end

  def other_chamber_vote
    actions.select { |a| (a.action_type == 'vote' and a.vote_type == 'vote2') }.last
  end

  def presented_to_president_action
    actions.select { |a| a.action_type == 'topresident' }.first
  end

  def signed_action
    actions.select { |a| a.action_type == 'signed' }.first
  end

  def vetoed_action
    actions.select { |a| a.action_type == 'vetoed' }.first
  end

  def override_vote
    actions.select { |a| (a.action_type == 'vote' and a.vote_type == 'override') }.first
  end

  def enacted_action
    actions.select { |a| a.action_type == 'enacted' }.last
  end

  # returns a hash with info on each step of the bill's progress
  def bill_status_hash
    status_hash = { "steps" => [] }
    current_step = 0

    if a = self.introduced_action
      status_hash['steps'] << { 'text' => 'Introduced', 'class' => 'passed first', 'date' => a.datetime }
    else
      status_hash['steps'] << { 'text' => 'Introduced', 'class' => 'passed first', 'date' => introduced_at }
    end

    status_hash['current_step'] = current_step
    current_step += 1

    if a = self.originating_chamber_vote
      roll_id = a.roll_call ? a.roll_call.id : ""

      if a.result == 'pass'
        status_hash['steps'] << { 'text' => "#{self.chamber.capitalize} Passed", 'result' => 'Passed',
            'class' => 'passed', 'date' => a.datetime, 'roll_id' => roll_id }
         unless (self.bill_type == 'hr' or self.bill_type == 's') # is resolution - is done
           status_hash['steps'] << { 'text' => 'Resolution<br/>Passed', 'result' => 'Passed', 'class' => 'is_res', 'date' => a.datetime, 'roll_id' => roll_id }
         end
      else
        status_hash['steps'] << { 'text' => " #{self.chamber.capitalize} Defeats", 'result' => 'Failed',
                                  'class' => 'failed', 'date' => a.datetime, 'roll_id' => roll_id }
      end

      status_hash['current_step'] = current_step
    else
      status_hash['steps'] << { 'text' => "#{self.chamber.capitalize} Passes",
                                'class' => 'pending', 'result' => 'Pending' }
      unless (self.bill_type == 'hr' or self.bill_type == 's') # is resolution pending
           status_hash['steps'] << { 'text' => 'Resolution Passed', 'class' => 'becomes_res', 'result' => 'Pending' }
      end
    end

    current_step += 1

    if (self.bill_type == 'hr' or self.bill_type == 's')
      if a = self.other_chamber_vote
        roll_id = a.roll_call ? a.roll_call.id : ""
        if a.result == 'pass'
          status_hash['steps'] << { 'text' => "#{self.other_chamber.capitalize} Passed", 'result' => 'Passed',
                                    'class' => 'passed', 'date' => a.datetime, 'roll_id' => roll_id }
        else
          status_hash['steps'] << { 'text' => "#{self.other_chamber.capitalize} Defeats", 'result' => 'Failed',
                                    'class' => 'failed', 'date' => a.datetime, 'roll_id' => roll_id }
        end

        status_hash['current_step'] = current_step
      else
        status_hash['steps'] << { 'text' => "#{self.other_chamber.capitalize} Passes",
                                  'class' => 'pending', 'result' => 'Pending' }
      end

      current_step += 1

      if a = self.signed_action
        status_hash['steps'] << { 'text' => 'President Signed', 'result' => 'Passed', 'class' => 'passed', 'date' => a.datetime }
        status_hash['current_step'] = current_step
      elsif a = self.vetoed_action
        status_hash['steps'] << { 'text' => 'President Vetoed', 'result' => 'Failed', 'class' => 'failed', 'date' => a.datetime }
        status_hash['current_step'] = current_step

        # check for overridden, otherwise, just return here
        if a = self.override_vote
          roll_id = a.roll_call ? a.roll_call.id : ""
          current_step += 1
          status_hash['current_step'] = current_step

          if a.result == 'pass'
            status_hash['steps'] << { 'text' => "Override Succeeds", 'result' => 'Passed',
                                      'class' => 'passed', 'date' => a.datetime, 'roll_id' => roll_id }
          else
            status_hash['steps'] << { 'text' => "Override Defeated", 'result' => 'Failed',
                                      'class' => 'failed', 'date' => a.datetime, 'roll_id' => roll_id }
            return status_hash
          end
        else
          return status_hash
        end
      else
        status_hash['steps'] << { 'text' => 'President Signs', 'class' => 'pending', 'result' => 'Pending' }
      end

      current_step += 1

      if a = self.enacted_action
        status_hash['steps'] << { 'text' => 'Bill Is Law', 'result' => 'Passed', 'class' => 'is_law', 'date' => a.datetime }
        status_hash['current_step'] = current_step
      else
        status_hash['steps'] << { 'text' => 'Bill Becomes Law', 'class' => 'becomes_law', 'result' => 'Pending' }
      end

    end

    return status_hash
  end

  def vote_on_passage(person)
    if (chamber == 'house' and person.title == 'Rep.') or (chamber == 'senate' and person.title = 'Sen.')
      roll = originating_chamber_vote
    else
      roll = other_chamber_vote
    end

    return "Not Voted Yet" if roll.nil? or roll.roll_call.nil?

    roll.roll_call.vote_for_person(person)
  end

  def self.full_text_search(q, options = {})
    congresses = options[:congresses] || Settings.default_congress

    s_count = Bill.count_by_sql(["SELECT COUNT(*) FROM bills, bill_fulltext
          WHERE bills.session IN (?) AND
            bill_fulltext.fti_names @@ to_tsquery('english', ?) AND
            bills.id = bill_fulltext.bill_id", options[:congresses] || Settings.default_congress, q])

    Bill.paginate_by_sql(["SELECT bills.*, rank(bill_fulltext.fti_names, ?, 1) as tsearch_rank FROM bills, bill_fulltext
                               WHERE bills.session IN (?) AND
                                     bill_fulltext.fti_names @@ to_tsquery('english', ?) AND
                                     bills.id = bill_fulltext.bill_id
                               ORDER BY hot_bill_category_id, lastaction DESC", q, options[:congresses], q],
                :per_page => Settings.default_search_page_size, :page => options[:page], :total_entries => s_count)
  end

  def billtext_txt
      begin
        # open html from file for now
        path = "#{GOVTRACK_BILLTEXT_PATH}/#{session}/#{bill_type}/"

        # use the symlink to find the current version of the text
        realpath = Pathname.new("#{path}/#{bill_type}#{number}.txt").realpath
        current_file = /\/([a-z0-9]*)\.txt/.match(realpath).captures[0]

        @bill_text ||= File.read(realpath)
      rescue
        @bill_text = nil
      end
      @bill_text
  end

  def self.b_rb
    Bill.rebuild_solr_index(10) do |bill, options|
      bill.find(:all, options.merge({:conditions => ["session = ?", Settings.default_congress]}))
    end
  end

  # fragment cache methods

  def fragment_cache_key
    "bill_#{id}"
  end

  def expire_govtrack_fragments
    fragments = []

    fragments << "#{fragment_cache_key}_header"

    FragmentCacheSweeper::expire_fragments(fragments)
  end

  def self.expire_meta_govtrack_fragments
    fragments = []

    fragments << "bill_all_index"

    FragmentCacheSweeper::expire_fragments(fragments)
  end

  def expire_commentary_fragments(type)
    FragmentCacheSweeper::expire_commentary_fragments(self, type)
  end

  # the following isn't called on an instance but rather, static-ly (sp?)
  def self.expire_meta_commentary_fragments
    commentary_types = ['news', 'blog']

    fragments = []

    fragments << "frontpage_bill_mostnews"
    fragments << "frontpage_bill_mostblogs"

    commentary_types.each do |ct|
      [7, 14, 30].each do |d|
        fragments << "bill_meta_most_#{ct}_#{d.days}"
      end
    end

    FragmentCacheSweeper::expire_fragments(fragments)
  end

  def obj_title
    typenumber
  end


  # methods about user interaction
  def users_at_position(position = 'support')
    bill_votes.count(:all, :conditions => ["support = ?", position == 'support' ? 0 : 1])
  end

  def users_percentage_at_position(position = 'support')
    vt = bill_votes.count
    if vt == 0
      result = nil
    else
      bs = users_at_position('support')
      bo = users_at_position('oppose')
      result = ((position == 'support' ? bs.to_f : bo.to_f) / vt) * 100
      result = result.round
    end
  end

  def as_json(ops = {})
    super(stylize_serialization(ops))
  end

  def as_xml(ops = {})
    super(stylize_serialization(ops))
  end

  private

  def stylize_serialization(ops)
   ops ||= {}
   style = ops.delete(:style) || :simple
   SERIALIZATION_STYLES[style].merge(ops)
  end

  def official_title
    bill_titles.select { |t| t.title_type == 'official' }.first
  end

  def short_title
    bill_titles.select { |t| t.title_type == 'short' }.first
  end

  def popular_title
    bill_titles.select { |t| t.title_type == 'popular' }.first
  end

  def default_title
    bill_titles.select { |t| t.is_default == true }.first
  end

  def self.chain_text_versions (versions)
    chain = []
    current_versions = [nil]
    while versions.present? do
      (these_versions, versions) = versions.partition{ |v| current_versions.include?(v.previous_version) }
      if these_versions.empty? and versions.present?
        raise Exception.new("Incomplete bill text version chain.")
      end
      chain.push(*these_versions)
      current_versions = these_versions.map{ |v| v.version }
    end
    return chain
  end

end