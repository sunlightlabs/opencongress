# == Schema Information
#
# Table name: subjects
#
#  id               :integer          not null, primary key
#  term             :string(255)
#  bill_count       :integer
#  fti_names        :public.tsvector
#  page_views_count :integer
#  parent_id        :integer
#

require_dependency 'viewable_object'
class Subject < ActiveRecord::Base
  include ViewableObject

  validates_uniqueness_of :term, :case_sensitive => false

  has_many :child_subjects, :class_name => 'Subject', :foreign_key => :parent_id
  belongs_to :parent, :class_name => 'Subject'

  has_many :bill_subjects
  has_many :bills, :through => :bill_subjects, :order => "bills.introduced DESC"

  has_many :users, :through => :bookmarks, :order => "bookmarks.created_at DESC"

  has_many :recently_introduced_bills, :class_name => "Bill", :through => :bill_subjects, :source => "bill", :order => "bills.introduced DESC", :limit => 20

  has_many :comments, :as => :commentable
  has_many :talking_points, :as => :talking_pointable

  has_many :groups
  has_one :issue_stats
  has_one :wiki_link

  has_many :pvs_category_mappings, :as => :pvs_category_mappable
  has_many :pvs_categories, :through => :pvs_category_mappings

  before_save :count_bills
  after_save :create_default_group, :if => :is_category?

  acts_as_bookmarkable

  scope :active, includes(:bills).where("bills.session" => Bill.available_sessions.last)
  scope :with_major_bills, includes(:bills).where(:bills => { :is_major => true })
  scope :top_level, lambda { where(:parent_id => Subject.root_category.id) }

  def is_category?
    is_child_of(Subject.root_category)
  end

  def default_group
    owner = User.find_by_login(Settings.default_group_owner_login)
    return if owner.nil?
    groups.where(:user_id => owner.id).first
  end

  def has_default_group?
    !default_group.nil?
  end

  def default_group_description
    "This is an automatically generated OpenCongress Group for tracking this issue area. Join this group to follow updates on major actions and key votes for related legislation and to connect with others interested."
  end

  def create_default_group
    if not has_default_group?
      owner = User.find_by_login(Settings.default_group_owner_login)
      return if owner.nil?

      grp = Group.new(:user_id => owner.id,
                      :name => "OpenCongress #{term} Group",
                      :description => default_group_description,
                      :join_type => "INVITE_ONLY",
                      :invite_type => "MODERATOR",
                      :post_type => "ANYONE",
                      :publicly_visible => true,
                      :subject_id => self.id
                     )
      grp.save!
    end
  end

  def self.root_category
    find_by_term("\u22a4")
  end

  def major_bills
    bills.where(:is_major => true)
  end

  @@DISPLAY_OBJECT_NAME = 'Issue'

  def is_child_of (other)
    parent == other
  end

  def display_object_name
    @@DISPLAY_OBJECT_NAME
  end

  def atom_id_as_feed
    # dates for issues don't make sense...just use 2007 for now
    "tag:opencongress.org,2007:/issue_feed/#{id}"
  end

  def atom_id_as_entry
    "tag:opencongress.org,2007:/issues/#{id}"
  end

  def ident
    "Issue #{id}"
  end

  def title_for_share
    term
  end

  def self.find_by_term_icase (term)
    first(:conditions => ['lower(term) = ?', term.downcase])
  end

  # TODO: Take this for a ride on the refactor tractor
  def self.find_all_by_most_tracked_for_range(range, options)
    range = 630720000 if range.nil?

    possible_orders = ["bookmark_count_1 asc", "bookmark_count_1 desc",
                       "total_comments asc", "total_comments desc"]
    logger.info options.to_yaml
    order = options[:order] ||= "bookmark_count_1 desc"
    search = options[:search]

    if possible_orders.include?(order)

      limit = options[:limit] ||= 20
      offset = options[:offset] ||= 0
      not_null_check = order.split(' ').first

      if search

        find_by_sql(["select subjects.*, rank(fti_names, ?, 1) as tsearch_rank, current_period.bookmark_count_1 as bookmark_count_1,
                     comments_total.total_comments as total_comments,
                     previous_period.bookmark_count_2 as bookmark_count_2
                     FROM subjects
                     INNER JOIN (select bookmarks.bookmarkable_id  as subject_id_1, count(bookmarks.bookmarkable_id) as bookmark_count_1
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_1) current_period ON subjects.id=current_period.subject_id_1
                     LEFT OUTER JOIN (select comments.commentable_id as subject_id_5, count(comments.*) as total_comments
                     FROM comments WHERE created_at > ? AND comments.commentable_type = 'Subject' GROUP BY comments.commentable_id) comments_total ON subjects.id=comments_total.subject_id_5
                     LEFT OUTER JOIN (select bookmarks.bookmarkable_id as subject_id_2, count(bookmarks.bookmarkable_id) as bookmark_count_2
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_2) previous_period ON subjects.id=previous_period.subject_id_2
                     WHERE #{not_null_check} is not null AND subjects.fti_names @@ to_tsquery('english', ?)
                     ORDER BY #{order} LIMIT #{limit} OFFSET #{offset}", search, range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago,
                     range.seconds.ago, search])

       else
        find_by_sql(["select subjects.*, current_period.bookmark_count_1 as bookmark_count_1,
                     comments_total.total_comments as total_comments,
                     previous_period.bookmark_count_2 as bookmark_count_2
                     FROM subjects
                     INNER JOIN (select bookmarks.bookmarkable_id  as subject_id_1, count(bookmarks.bookmarkable_id) as bookmark_count_1
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_1) current_period ON subjects.id=current_period.subject_id_1
                     LEFT OUTER JOIN (select comments.commentable_id as subject_id_5, count(comments.*) as total_comments
                     FROM comments WHERE created_at > ? AND comments.commentable_type = 'Subject' GROUP BY comments.commentable_id) comments_total ON subjects.id=comments_total.subject_id_5
                     LEFT OUTER JOIN (select bookmarks.bookmarkable_id as subject_id_2, count(bookmarks.bookmarkable_id) as bookmark_count_2
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_2) previous_period ON subjects.id=previous_period.subject_id_2
                     WHERE #{not_null_check} is not null order by #{order} LIMIT #{limit} OFFSET #{offset}", range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago,
                     range.seconds.ago])
        end
     else
       return []
     end
  end

  # TODO: Make me a .count on the above scope
  def self.count_all_by_most_tracked_for_range(range, options)
    range = 630720000 if range.nil?

    possible_orders = ["bookmark_count_1 asc", "bookmark_count_1 desc",
                       "total_comments asc", "total_comments desc"]
    logger.info options.to_yaml
    order = options[:order] ||= "bookmark_count_1 desc"
    search = options[:search]

    if possible_orders.include?(order)

      limit = options[:limit] ||= 20
      offset = options[:offset] ||= 0
      not_null_check = order.split(' ').first

      if search

        count_by_sql(["select count(subjects.*)
                     FROM subjects
                     INNER JOIN (select bookmarks.bookmarkable_id  as subject_id_1, count(bookmarks.bookmarkable_id) as bookmark_count_1
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_1) current_period ON subjects.id=current_period.subject_id_1
                     LEFT OUTER JOIN (select comments.commentable_id as subject_id_5, count(comments.*) as total_comments
                     FROM comments WHERE created_at > ? AND comments.commentable_type = 'Subject' GROUP BY comments.commentable_id) comments_total ON subjects.id=comments_total.subject_id_5
                     LEFT OUTER JOIN (select bookmarks.bookmarkable_id as subject_id_2, count(bookmarks.bookmarkable_id) as bookmark_count_2
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_2) previous_period ON subjects.id=previous_period.subject_id_2
                     WHERE #{not_null_check} is not null AND subjects.fti_names @@ to_tsquery('english', ?)
                     LIMIT #{limit} OFFSET #{offset}", range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago,
                     range.seconds.ago, search])

       else
        count_by_sql(["select count(subjects.*)
                     FROM subjects
                     INNER JOIN (select bookmarks.bookmarkable_id  as subject_id_1, count(bookmarks.bookmarkable_id) as bookmark_count_1
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_1) current_period ON subjects.id=current_period.subject_id_1
                     LEFT OUTER JOIN (select comments.commentable_id as subject_id_5, count(comments.*) as total_comments
                     FROM comments WHERE created_at > ? AND comments.commentable_type = 'Subject' GROUP BY comments.commentable_id) comments_total ON subjects.id=comments_total.subject_id_5
                     LEFT OUTER JOIN (select bookmarks.bookmarkable_id as subject_id_2, count(bookmarks.bookmarkable_id) as bookmark_count_2
                     FROM bookmarks where created_at > ? AND created_at <= ? group by subject_id_2) previous_period ON subjects.id=previous_period.subject_id_2
                     WHERE #{not_null_check} is not null LIMIT #{limit} OFFSET #{offset}", range.seconds.ago, Time.now, range.seconds.ago, (range*2).seconds.ago,
                     range.seconds.ago])
        end
     else
       return []
     end
  end

  def self.count_all_by_most_tracked_for_range2(range, options)
    possible_orders = ["bookmark_count_1 asc", "bookmark_count_1 desc",
                       "total_comments asc", "total_comments desc"]
    logger.info options.to_yaml
    order = options[:order] ||= "bookmark_count_1 desc"
    if possible_orders.include?(order)

      limit = options[:limit] ||= 20
      offset = options[:offset] ||= 0
      if order =~ /comments/
        includes = [:comments]
        conditions = ["comments.created_at > ? AND comments.created_at <= ?", range.seconds.ago, Time.now]
      elsif order =~ /bookmark/
        includes = [:bookmarks]
        conditions = ["bookmarks.created_at > ? AND bookmarks.created_at <= ?", range.seconds.ago, Time.now]
      end

      Subject.count(:all, :include => includes, :conditions => conditions)
    else
      return 0
    end
  end

  # TODO: Banish all find_by_sql from this project
  def Subject.find_by_most_comments_for_range(range, order = "total_comments")
    not_null_check = "vote_count_1"
    not_null_check = "total_comments" if order == "total_comments"
    Subject.find_by_sql(["select subjects.*, comments_total.comment_count_1 as comment_count FROM subjects
                      INNER JOIN (select comments.commentable_id as commentable_id, count(comments.commentable_id) as comment_count_1 from comments
                         WHERE comments.created_at > ? AND comments.commentable_type = 'Subject' GROUP BY comments.commentable_id) comments_total ON comments_total.commentable_id = subjects.id
                         ORDER BY comment_count DESC LIMIT 30;", range.seconds.ago])
  end

  def Subject.random(limit)
    Subject.find_by_sql ["SELECT * FROM (SELECT random(), subjects.* FROM subjects ORDER BY 1) as bs LIMIT ?;", limit]
  end

  def Subject.find_by_first_letter(letter)
    Subject.find(:all, :conditions => ["upper(term) LIKE ?", "#{letter}%"], :order => "term asc")
  end

  def Subject.by_bill_count
    Subject.find(:all, :order => "bill_count desc, term asc")
  end

  def Subject.alphabetical
    Subject.find(:all, :order => "term asc")
  end

  def Subject.top20_viewed
    issues = ObjectAggregate.popular('Subject')

    (issues.select {|b| b.stats.entered_top_viewed.nil? }).each do |bv|
      bv.stats.entered_top_viewed = Time.now
      bv.save
    end

    (issues.sort { |i1, i2| i2.stats.entered_top_viewed <=> i1.stats.entered_top_viewed })
  end

  # TODO
  def Subject.top20_tracked
    Subject.find_by_sql("SELECT subjects.id, subjects.term, COUNT(bookmarks.id) as bookmark_count from subjects inner join bookmarks on subjects.id = bookmarks.bookmarkable_id WHERE bookmarks.bookmarkable_type = 'Subject' group by subjects.id, subjects.term ORDER BY bookmark_count desc LIMIT 20")
    #:all, :joins => "INNER JOIN bookmarks on subjects.id = bookmarks.bookmarkable_id", :conditions => "bookmarks.bookmarkable_type = 'Subject'", :select => "COUNT(bookmarks.id) as bookmark_count, subjects.*", :order => "COUNT(bookmarks.id) DESC", :group => "bookmarks.bookmarkable_id HAVING bookmark_count > 5", :limit => 10)
  end
  def stats
    unless issue_stats
      self.issue_stats = IssueStats.new :subject => self
    end

    issue_stats
  end

  # Returns the number of people tracking this bill, as well as suggestions of what other people
  # tracking this bill are also tracking.
  # TODO: This probably has no footprint, because it's broken, but find a way to do this without solr
  def tracking_suggestions
    # temporarily removing solr for now - June 2012
    return [0, {}]

    facet_results_hsh = {:my_people_tracked_facet => [], :my_issues_tracked_facet => [], :my_bills_tracked_facet => []}
    my_trackers = 0

    begin
      users = User.find_by_solr('[* TO *]', :facets => {:fields => [:my_people_tracked, :my_issues_tracked, :my_bills_tracked], :browse => ["my_issues_tracked:#{id}"], :limit => 6, :zeros => false, :sort =>  true}, :limit => 1)
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
          if key == id.to_s && fkey == "my_issues_tracked_facet"
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


  def related_subjects(number)
    SubjectRelation.related(self, number)
  end

  def all_related_subjects()
    SubjectRelation.all_related(self)
  end

  def latest_bills(num, page = 1, congress = [ Settings.default_congress ])
    bills.find(:all, :conditions => ['bills.session IN (?)', congress],
               :order => 'bills.lastaction DESC').paginate(:per_page => num, :page => page)
  end

  def passed_bills(num, page = 1, congress = [ Settings.default_congress ])
    bills.find(:all, :include => :actions, :conditions => ["bills.session IN (?) AND actions.action_type='enacted'", congress],
               :order => 'actions.datetime DESC').paginate(:per_page => num, :page => page)
  end

  def newest_bills(num, congress = Settings.default_congress)
    bills.find(:all, :conditions => ['bills.session = ?', congress], :order => 'bills.introduced DESC', :limit => num);
  end

  def new_bills_since(current_user, congress = Settings.default_congress)
    time_since = current_user.previous_login_date
    time_since = 200.days.ago if Rails.env.development?

    bills.find(:all, :include => [:actions],
                     :conditions => ['bills.session = ? AND actions.datetime > ? AND actions.action_type = ?', congress, time_since, 'introduced'],
                     :order => 'bills.introduced DESC',
                     :limit => 20);
  end

  def comments_since(current_user)
    self.comments.count(:id, :conditions => ["created_at > ?", current_user.previous_login_date])
  end

  def key_votes(congress = Settings.default_congress)
    major_bills.includes(:roll_calls)
               .order('roll_calls.date desc')
               .where('roll_calls.roll_type' => RollCall.passage_types)
               .first(10)
               .map{ |b| b.roll_calls.last }
               .select{ |r| r.nil? == false}
  end

  # TODO
  def most_viewed_bills(num = 5, congress = Settings.default_congress, seconds = Settings.default_count_time)
    Bill.find_by_sql(["SELECT bills.*,
                              most_viewed.view_count AS view_count
                       FROM bills
                       INNER JOIN
                       (SELECT object_aggregates.aggregatable_id,
                               sum(object_aggregates.aggregatable_id) AS view_count
                        FROM object_aggregates
                        WHERE object_aggregates.date >= ? AND
                              object_aggregates.aggregatable_type = 'Bill'
                        GROUP BY object_aggregates.aggregatable_id
                        ORDER BY view_count DESC) most_viewed
                       ON bills.id=most_viewed.aggregatable_id
                       INNER JOIN bill_subjects ON bill_subjects.bill_id=bills.id
                       WHERE bills.session=? AND bill_subjects.subject_id=?
                       ORDER BY view_count DESC
                       LIMIT ?",
                      seconds.ago, congress, id, num])
  end

  # TODO
  def latest_major_actions(num)
    Action.find_by_sql( ["SELECT actions.* FROM actions, bill_subjects, bills
                                    WHERE bill_subjects.subject_id = ? AND
                                          (actions.action_type = 'introduced' OR
                                           actions.action_type = 'topresident' OR
                                           actions.action_type = 'signed' OR
                                           actions.action_type = 'enacted' OR
                                           actions.action_type = 'vetoed') AND
                                           actions.bill_id = bills.id AND
                                          bill_subjects.bill_id = bills.id
                                    ORDER BY actions.date DESC
                                    LIMIT #{num}", id])
    #logger.info actions.inspect
    #actions.collect { |a| a.bill }
  end

  def count_bills (options = Hash.new)
    congress = options.fetch(:congress, Settings.default_congress)
    self.bill_count = id ? bills.where(:session => congress).count : 0
  end

  def self.update_bill_counts (options = Hash.new)
    congress = options.fetch(:congress, Settings.default_congress)
    cnt = 0
    Subject.transaction {
      Subject.all.each do |subj|
        subj.save!
        cnt = cnt + 1
      end
    }
    cnt
  end

  def summary
    #placeholder
  end

  def to_param
    "#{id}_#{url_name}"
  end

  # TODO
  def self.full_text_search(q, options = {})
    subjects = Subject.paginate_by_sql(["SELECT subjects.*, rank(fti_names, ?, 1) as tsearch_rank FROM subjects
                                 WHERE subjects.fti_names @@ to_tsquery('english', ?)
                                 ORDER BY tsearch_rank DESC, term ASC", q, q],
                                :per_page => options[:per_page].nil? ? Settings.default_search_page_size : options[:per_page],
                                :page => options[:page])
    subjects
  end

  def recent_blogs
    Commentary.where(commentariable_id: Subject.find_by_id(5029).recently_introduced_bills.collect {|p| p.id},
                     commentariable_type: 'Bill',
                     is_ok: true,
                     is_news: false).order('created_at DESC').limit(10)
  end

  def recent_news
    Commentary.where(commentariable_id: Subject.find_by_id(5029).recently_introduced_bills.collect {|p| p.id},
                     commentariable_type: 'Bill',
                     is_ok: true,
                     is_news: false).order('created_at DESC').limit(10)
  end

  private
  def url_name
    term.gsub(/[\.\(\)]/, "").gsub(/[-\s]+/, "_").downcase
  end
end
