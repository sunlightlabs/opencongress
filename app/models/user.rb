# == Schema Information
#
# Table name: users
#
#  id                    :integer          not null, primary key
#  login                 :string(255)
#  email                 :string(255)
#  crypted_password      :string(40)
#  salt                  :string(40)
#  created_at            :datetime
#  updated_at            :datetime
#  remember_token        :string(255)
#  remember_created_at   :datetime
#  status                :integer          default(0)
#  last_login            :datetime
#  activation_code       :string(40)
#  activated_at          :datetime
#  password_reset_code   :string(40)
#  user_role_id          :integer          default(0)
#  representative_id     :integer
#  previous_login_date   :datetime
#  identity_url          :string(255)
#  accepted_tos_at       :datetime
#  authentication_token  :string(255)
#  facebook_uid          :string(255)
#  state                 :string(2)
#  district              :integer
#  district_needs_update :boolean          default(FALSE)
#  possible_states       :text
#  possible_districts    :text
#

require 'digest/sha1'
require_dependency 'authable'
require_dependency 'email_listable'
require_dependency 'multi_geocoder'
require_dependency 'visible_by_privacy_option_query'

# this model expects a certain database layout and its based on the name/login pattern.
class User < ActiveRecord::Base
  include Authable
  include EmailListable


  # Validators

  validates_presence_of       :login, :email, :unless => :openid?
  # validates_confirmation_of   :email, :message => 'should match confirmation'
  validates_acceptance_of     :accept_tos,                 :unless => :openid?
  validates_presence_of       :password,                   :if => :password_required?
  validates_length_of         :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of   :password,                   :if => :password_required?
  validates_length_of         :login,    :within => 3..40, :unless => :openid?
  validates_length_of         :email,    :within => 3..100, :unless => :openid?
  validates_format_of         :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :message => "is invalid"
  validates_format_of         :login, :with => /^\w+$/, :message => "can only contain letters and numbers (no spaces)."
  validates_uniqueness_of     :login, :email, :identity_url, :case_sensitive => false, :allow_nil => true

  HUMANIZED_ATTRIBUTES = {
    :email => "E-mail address",
    :accept_tos => "Terms of service",
    :login => "Username"
  }


  # Callbacks

  update_email_subscription_when_changed :self, [:email]
  # on ban or delete, clean up this user's associations with various parts of the site
  after_save Proc.new {
    privatize!
    destroy_comments!
    destroy_friendships!
    destroy_friend_invites!
    destroy_group_invites!
    destroy_group_memberships!
    reassign_groups!
    disable_mailing_list!
    destroy_notebook_items!
    destroy_political_notebook!
    destroy_twitter_config!
  }, :if => Proc.new { (is_banned? || is_deactivated?) && status_changed? }


  # Relations

  has_one  :user_profile
  has_one  :user_privacy_options
  has_one  :user_options
  has_one  :user_mailing_list
  has_one  :twitter_config
  has_one  :latest_ip_address, :class_name => "UserIpAddress", :order => "created_at DESC"

  has_many :owned_groups, :class_name => 'Group'
  has_many :group_members
  has_many :groups, :through => :group_members
  has_many :group_invites
  has_many :api_hits
  has_many :comments, :dependent => :destroy
  has_many :commentary_ratings
  has_many :comment_scores
  has_many :user_ip_addresses
  has_many :friends
  has_many :friend_invites, :foreign_key => "inviter_id"
  has_many :fans, :class_name => "Friend", :foreign_key => "friend_id", :conditions => ["confirmed = ?", false]
  has_many :person_approvals
  has_many :bookmarks
  has_many :senator_bookmarks, :class_name => "Bookmark", :foreign_key => "user_id", :include => [:person => :roles], :conditions => proc { ["roles.role_type = ? and roles.startdate < ? and roles.enddate > ?", "sen", Time.now, Time.now] }
  has_many :representative_bookmarks, :class_name => "Bookmark", :foreign_key => "user_id", :include => [:person => :roles], :conditions => proc { ["roles.role_type = ? and roles.startdate < ? and roles.enddate > ?", "rep", Time.now, Time.now] }
  has_many :legislator_bookmarks, :class_name => "Bookmark", :foreign_key => "user_id", :include => [:person => :roles], :conditions => proc { ["roles.role_type in(?) and roles.startdate < ? and roles.enddate > ?", ["sen", "rep"], Time.now, Time.now] }
  has_many :bill_bookmarks, :class_name => "Bookmark", :foreign_key => "user_id", :conditions => "bookmarks.bookmarkable_type = 'Bill'"
  has_many :issue_bookmarks, :class_name => "Bookmark", :foreign_key => "user_id", :conditions => "bookmarks.bookmarkable_type = 'Subject'"
  has_many :committee_bookmarks, :class_name => "Bookmark", :foreign_key => "user_id", :conditions => "bookmarks.bookmarkable_type = 'Committee'"
  has_many :watched_districts, :class_name => "WatchDog"
  has_many :bill_votes
  # TODO: The original implementation included the number of people who have bookmarked the bill, which should be done differently
  has_many :bookmarked_bills, :class_name => "Bill", :through => :bookmarks, :source => :bill, :order => "bookmarks.created_at DESC"
  has_many :bills_voted_on, :class_name => "Bill", :through => :bill_votes, :source => :bill, :order => "bill_votes.created_at DESC"
  # Support = 0 for support, 1 for oppose. Not even kidding.
  has_many :bills_supported, :class_name => "Bill", :through => :bill_votes, :source => :bill, :conditions => ["bill_votes.support = 0"], :order => "bill_votes.created_at DESC"
  has_many :bills_opposed, :class_name => "Bill", :through => :bill_votes, :source => :bill, :conditions => ["bill_votes.support = 1"], :order => "bill_votes.created_at DESC"
  has_many :bookmarked_people, :class_name => "Person", :through => :bookmarks, :source => :person, :conditions => ["bookmarks.bookmarkable_type = 'Person'"], :order => "bookmarks.created_at DESC"
  has_many :bookmarked_issues, :class_name => "Subject", :through => :bookmarks, :source => :subject, :conditions => ["bookmarks.bookmarkable_type = 'Subject'"], :order => "bookmarks.created_at DESC"
  has_many :bookmarked_committees, :class_name => "Committee", :through => :bookmarks, :source => :committee, :conditions => ["bookmarks.bookmarkable_type = 'Committee'"], :order => "bookmarks.created_at DESC"

  belongs_to :representative, :class_name => "Person", :foreign_key => "representative_id"
  belongs_to :user_role
  has_one    :watch_dog
  has_many   :user_warnings

  has_one    :political_notebook, :dependent => :destroy
  has_many   :notebook_items, :through => :political_notebook

  has_many   :contact_congress_letters

  alias_attribute :username, :login

  # These are just here for some consistency in naming patterns
  alias_method :voted_bills, :bills_voted_on
  alias_method :supported_bills, :bills_supported
  alias_method :opposed_bills, :bills_opposed


  # Scopes

  scope :for_state, lambda {|state| where("state = ?", state.upcase) }
  scope :for_district, lambda {|state, district| for_state(state).where("district = ?", district.to_i) }
  scope :active, lambda { where("previous_login_date >= ?", 1.months.ago) }
  scope :inactive, lambda { where("previous_login_date < ? OR previous_login_date IS NULL", 3.months.ago)}
  scope :tracking_bill, lambda {|bill| includes(:bookmarked_bills).where("bills.id" => bill.id) }
  scope :voted_on_bill, lambda {|bill| includes(:bills_voted_on).where("bills.id" => bill.id) }
  scope :supporting_bill, lambda {|bill| includes(:bills_supported).where("bills.id" => bill.id) }
  scope :opposing_bill, lambda {|bill| includes(:bills_opposed).where("bills.id" => bill.id) }
  scope :supporting_person, lambda{|person| includes(:person_approvals).where("person_approvals.person_id" => person.id).where("rating > 5")}
  scope :opposing_person, lambda{|person| includes(:person_approvals).where("person_approvals.person_id" => person.id).where("rating > 5")}
  scope :ranking_person, lambda{|person| includes(:person_approvals).where("person_approvals.person_id" => person.id).where("rating is not null")}
  scope :tracking_person, lambda {|person| includes(:bookmarked_people).where("people.id" => person.id) }
  scope :tracking_issue, lambda {|subject| includes(:bookmarked_issues).where("subjects.id" => subject.id) }
  scope :tracking_committee, lambda {|committee| includes(:bookmarked_committees).where("committees.id" => committee.id) }

  scope :mypn_spammers, includes(:political_notebook => [:notebook_items]).where("notebook_items.spam = ?", true).order("users.login ASC")

  # These are LoD helpers that just pass on AR relations from Person
  def bookmarked_senators; bookmarked_people.sen; end
  def bookmarked_representatives; bookmarked_people.rep; end


  # Accessors

  # Note that some attrs are defined in authable_model
  # accept_tos and email_confirmation are unpersisted accessors for validation only
  attr_accessible :email, :accept_tos, :accepted_tos_at, :remember_created_at,
                  :representative_id, :state, :district, :user_privacy_options_attributes,
                  :user_options_attributes, :user_profile_attributes

  attr_accessor :accept_tos, :email_confirmation

  accepts_nested_attributes_for :user_privacy_options, :user_profile, :user_options

  serialize :possible_states
  serialize :possible_districts


  # Delegated Methods

  delegate :privatize!, :to => :user_privacy_options

  ##
  # TODO: Enable the below delegations after remapping user data to external classes!
  # (After migration #20140424162910)
  ##

  %w(zipcode zip_four street_address street_address_2 small_picture main_picture
     first_name last_name full_name website about city coordinates location address mobile_phone).each do |prop|
    delegate prop.to_sym, :to => :user_profile
  end

  %w(comment_threshold opencongress_mail partner_mail sms_notifications email_notifications feed_key).each do |prop|
    delegate prop.to_sym, :to => :user_options
  end

  %w(name email zipcode location profile actions tracked_items
     friends political_notebook watchdog).each do |prop|
    delegate prop.to_sym, :to => :user_privacy_options, :prefix => :share
  end


  # create related class instances on first access
  %w(user_profile user_options user_privacy_options).each do |meth|
    alias_method(:"_#{meth}", meth.to_sym)
    define_method(meth.to_sym){ send(:"_#{meth}") || send(:"build_#{meth}")}
  end


  class << self
    def random_password
      password = SecureRandom.random_number(178689910246017054531432477289437798228285773001601743140683775).to_s(36)
    end

    def login_stub_for_profile (profile)
      address = Mail::Address.new(profile.email)
      stub = address.local.sub(/[^a-z0-9].*$/i, '') # remove any non-alphnumeric character and everything following it
      if stub.length < 5
        # In case we stripped off too much, or their email address is just ridiculously short
        stub = "#{profile.first_name}#{profile.last_name.first}"
      end
      stub
    end

    def unused_login (stub, max_attempts=100)
      candidate = stub
      (0..max_attempts).each do |attempt|
        user = User.find_by_login(candidate)
        if user.nil?
          return candidate
        end
        candidate = stub + SecureRandom.random_number(9999).to_s(10)
      end
      return nil
    end

    def generate_for_profile (profile)
      begin
        user = User.new(:login => unused_login(login_stub_for_profile(profile)),
                        :email => profile.email,
                        :password => random_password,
                        :accepted_tos_at => profile.accept_tos && Time.now || nil,
                        :full_name => profile.full_name,
                        :state => profile.state,
                        :zipcode => profile.zipcode,
                        :zip_four => profile.zip_four)
        user.save!
        # TODO: bundle this in a transaction and save the UserProfile too.
        return user
      rescue ActiveRecord::RecordInvalid => e
        if e.record.errors[:login].include?('has already been taken')
          retry
        else
          raise
        end
      end
    end

    def highest_rated_commenters
      cs = CommentScore.calculate(:count, :score, :include => "comment", :group => "comments.user_id", :order => "count_score DESC").collect {|p| p[1] > 3 && p[0] != nil ? p[0] : nil}.compact
      CommentScore.calculate(:avg, :score, :include => "comment", :group => "comments.user_id", :conditions => ["comments.user_id in (?)", cs], :order => "avg_score DESC").each do |k|
        puts "#{User.find_by_id(k[0]).login} - Average Rating: #{k[1]}"
      end
    end

    def find_all_by_ip(address)
       ip = UserIpAddress.int_form(address)
       self.find(:all, :include => [:user_ip_addresses], :conditions => ["user_ip_addresses.addr = ?", ip])
    end

    def find_by_feed_key_option(key)
      self.includes(:user_options).where("user_options.feed_key = ?", key)
    end
  end # class << self

  def placeholder
    "placeholder"
  end

  def picture_path(size=:main)
    filename = send("#{size}_picture".to_sym)
    "users/#{filename}"
  end

  def action_count
    comments.count + friends.count + bill_votes.count + person_approvals.count + bookmarks.count
  end

  def accepted_tos?
    accepted_tos_at.present?
  end

  # permissions method
  def can_view(option, viewer)
    res = false
    if viewer.nil? or (viewer == :false)
      #logger.info "tis nil"
      if user_privacy_options[option] == 2
        #logger.info "tis allowed"
        res = true
      else
        #logger.info "tis not allowed"
        res = false
      end
    elsif viewer[:id] == self[:id]
      res = true
    elsif friends.find_by_friend_id(viewer[:id]) && send(:"share_#{option}") >= 1
      res = true
    elsif send(:"share_#{option}") == 2
      res = true
    else
      res = false
    end
    return res
  end

  # DEPRECATED: use only on the users tracking x are also tracking y friends pages /friends/tracking_person, etc.
  def can_view_special(field)
    if self[field] == '2' || ( self[field] == '1' && (self['is_friend'] && self['is_friend_confirmed'] == 't'))
      return true
    else
      return false
    end
  end

  def active_groups
    owned_groups + groups.includes(:user).where("group_members.status != 'BOOTED'").select{ |g| not g.user.is_banned? }
  end

  def join_default_groups
    if state.present?
      state_group = State.find_by_abbreviation(state).group rescue nil
      unless state_group.nil? or state_group.users.include?(self)
        state_group.group_members.create(:user_id => id, :status => 'MEMBER')
      end
    end

    if district.present?
      district_group = District.find_by_district_tag(district_tag).group rescue nil
      unless district_group.nil? or district_group.users.include?(self)
        district_group.group_members.create(:user_id => id, :status => 'MEMBER')
      end
    end
  end

  def district_tag
    "#{state}-#{district}"
  end

  # TODO: Deprecate me
  def zip5_districts
    Congress.districts_locate(zipcode).results rescue []
  end

  # TODO: Deprecate me
  def my_state
    state || zip5_districts.collect(&:state).uniq rescue []
  end

  # TODO: Deprecate me
  def my_district
    if state.present? && district.present?
      ["#{state}-#{district}"]
    else
      zip5_districts.collect {|p| "#{p.state}-#{p.district}"} rescue []
    end
  end

  # TODO: Deprecate me
  def my_district_number
    zip5_districts.collect(&:district)
  end

  # TODO: Deprecate me
  def definitive_district
    if my_district.compact.length == 1
       t_state, t_district = my_district.first.split('-')
       this_state = State.find_by_abbreviation(t_state)
       this_district = this_state.districts.find_by_district_number(t_district) if this_state
       if this_district
         return this_district.id
       else
         return nil
       end
    else
      return nil
    end

  end

  # TODO: Deprecate me
  def my_state_f
    my_state
  end

  # TODO: Deprecate me
  def my_district_f
    my_district
  end

  # TODO: Deprecate me
  def definitive_district_object
    if my_district.compact.length == 1
       t_state, t_district = my_district.first.split('-')
       this_state = State.find_by_abbreviation(t_state)
       this_district = this_state.districts.find_by_district_number(t_district) if this_state
       if this_district
         return this_district
       else
         return nil
       end
    else
      return nil
    end
  end

  def friends_in_state(state = self.my_state)
    friends_logins = friends.collect{|p| "login:#{p.friend.login}"}
    unless friends_logins.empty?
      User.find_by_solr("#{friends_logins.join(' OR ')}",
           :facets => {:browse => ["my_state_f:\"#{my_state}\""]}, :limit => 100).results
    else
      return []
    end
  rescue
    return []
  end

  def friends_in_district(district = self.my_district)
    unless self.my_district.empty?
      friends_logins = friends.collect{|p| "login:#{p.friend.login}"}
      unless friends_logins.empty?
        User.find_by_solr("#{friends_logins.join(' OR ')}",
          :facets => {:browse => ["my_district_f:#{my_district}"]}, :limit => 100).results
      else
        return []
      end
    else
      return []
    end
  end

  def my_sens
    Person.find_current_senators_by_state(my_state)
  end
  def my_reps
    Person.find_current_representatives_by_state_and_district(state, district)
  end
  def my_congress_members
    [my_sens, my_reps].compact.flatten
  end

  def my_approved_reps
    person_approvals.find(:all, :include => [:person], :conditions => ["people.name LIKE ? AND rating > 5", '%Rep.%']).collect {|p| p.person.id}
  end

  def my_disapproved_reps
    person_approvals.find(:all, :include => [:person], :conditions => ["people.name LIKE ? AND rating <= 5", '%Rep.%']).collect {|p| p.person.id}
  end

  def my_approved_sens
    person_approvals.find(:all, :include => [:person], :conditions => ["people.name LIKE ? AND rating > 5", '%Sen.%']).collect {|p| p.person.id}
  end

  def my_disapproved_sens
    person_approvals.find(:all, :include => [:person], :conditions => ["people.name LIKE ? AND rating <= 5", '%Sen.%']).collect {|p| p.person.id}
  end

  def public_actions
    can_view(:actions, nil)
  end

  def my_bills_supported
    bills_supported..map(&:id)
  end

  def my_bills_opposed
    bills_opposed.map(&:id)
  end

  def my_bills_tracked
    bookmarked_bills.map(&:ident)
  end

  def my_committees_tracked
    bookmarked_committees.map(&:id)
  end

  def my_people_tracked
    bookmarked_people.map(&:id)
  end

  def my_issues_tracked
    bookmarked_issues.map(&:id)
  end

  def public_tracking
    if user_privacy_options.tracked_items == 2
       return true
    else
       return false
    end
  end

  def votes_like_me
    req = []
    my_bills_supported.each do |b|
      req << "my_bills_supported:#{b}"
    end
    my_bills_opposed.each do |b|
      req << "my_bills_opposed:#{b}"
    end

    unless req.empty?
      query = req.join(' OR ')
      return User.find_by_solr(query, :scores => true, :limit => 31, :facets => {:zeros => true, :browse => ["public_actions:true"] }).results
    else
      return nil
    end
  end

  def find_other_users_in_state(state)
    User.find_by_sql(['select distinct users.id, users.login from users where state like ?;', "%#{state}%"])
  end

  def find_other_users_in_district(state, district)
    User.find_by_sql(['select distinct users.id, users.login from users where state like ? and district = ?;', "%#{state}%", district])
  end

  def senator_bookmarks_count
    current_user.bookmarks.count(:all, :include => [{:person => :roles}], :conditions => ["roles.role_type = ?", "sen"])
  end
  def representative_bookmarks_count
    current_user.bookmarks.count(:all, :include => [{:person => :roles}], :conditions => ["roles.role_type = ?", "rep"])
  end

  def recent_actions(limit = 10)
    b = bookmarks.find(:all, :order => "created_at DESC", :limit => limit)
    c = comments.find(:all, :order => "created_at DESC", :limit => limit)
    bv = bill_votes.find(:all, :order => "created_at DESC", :limit => limit)
    pa = person_approvals.find(:all, :order => "created_at DESC", :limit => limit)
    f = friends.find(:all, :conditions => ["confirmed = ?", true], :order => "confirmed_at DESC", :limit => limit)
    l = contact_congress_letters.order('created_at DESC').limit(limit)

    items = b.concat(c).concat(bv).concat(pa).concat(f).concat(l).compact
    items.sort! { |x,y| y.created_at <=> x.created_at }
    return items
  end

  def recent_public_actions(limit = 10)
#    b = self.bookmarks.find(:all, :order => "created_at DESC", :limit => limit)
    c = comments.find(:all, :order => "created_at DESC", :limit => limit)
    bv = bill_votes.find(:all, :order => "created_at DESC", :limit => limit)
#    pa = person_approvals.find(:all, :order => "created_at DESC", :limit => limit)
    f = friends.find(:all, :conditions => ["confirmed = ?", true], :order => "confirmed_at DESC", :limit => limit)
    items = c.concat(bv).concat(f).compact
    items.sort! { |x,y| y.created_at <=> x.created_at }
    return items
  end

  def comment_warn(comment, admin)
    user_warnings.create({:warning_message => "Comment Warning for Comment #{comment.id}", :warned_by => admin.id})
    UserNotifier.comment_warning(self, comment).deliver
  end

  def self.fix_duplicate_users
    User.find_by_sql('select login, COUNT(*) as r1_tally FROM users GROUP BY login HAVING COUNT(*) > 1 ORDER BY r1_tally desc;').each do |k|
      puts k.login
      number = k.r1_tally.to_i
      User.find_all_by_login(k.login, :order => "created_at desc").each do |j|
         number = number - 1
         j.destroy unless number == 1
      end
    end

    User.find_by_sql('select email, COUNT(*) as r1_tally FROM users GROUP BY email HAVING COUNT(*) > 1 ORDER BY r1_tally desc;').each do |k|
      puts k.email
      number = k.r1_tally.to_i
      User.find_all_by_email(k.email, :order => "created_at desc").each do |j|
         number = number - 1
         j.destroy unless number == 1
      end
    end

    User.find_by_sql('select lower(login) as login, COUNT(*) as r1_tally FROM users GROUP BY login HAVING COUNT(*) > 1 ORDER BY r1_tally desc;').each do |k|
      next if k.nil?
      puts k.login
      number = k.r1_tally.to_i
      k.destroy if k.activated_at.nil?
    end
  end

  def password_required?
    !openid? && !facebook_connect_user? && (crypted_password.blank? || !password.blank?)
  end

  def openid?
   !identity_url.blank?
  end

  def facebook_connect_user?
    !facebook_uid.blank?
  end


  private

  def destroy_comments!
    comments.destroy_all
  end

  def privatize_contact_congress_letters!
    contact_congress_letters.update_all(:is_public => false)
  end

  def destroy_friendships!
    friends.destroy_all
  end

  def destroy_friend_invites!
    friend_invites.destroy_all
  end

  def destroy_group_invites!
    group_invites.destroy_all
  end

  def destroy_group_memberships!
    groups = []
  end

  def disable_mailing_list!
    user_mailing_list.update_attribute(:status, UserMailingList::DISABLED) rescue nil
  end

  def reassign_groups!
    # TODO: this should get managed at the controller layer, leaving it here as a reminder.
  end

  def destroy_notebook_items!
    political_notebook.notebook_items.destroy_all rescue nil
  end

  def destroy_political_notebook!
    political_notebook.destroy rescue nil
  end

  def destroy_twitter_config!
    twitter_config.destroy rescue nil
  end

end
