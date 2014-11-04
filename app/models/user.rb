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
#  possible_states       :text
#  possible_districts    :text
#  state                 :string(2)
#  district              :integer
#  district_needs_update :boolean          default(FALSE)
#  password_digest       :string(255)
#

require_dependency 'authable'
require_dependency 'email_listable'
require_dependency 'visible_by_privacy_option_query'

class User < OpenCongressModel

  #========== INCLUDES

  include Authable
  include EmailListable
  include PrivacyObject
  apply_simple_captcha

  #========== CONSTANTS

  HUMANIZED_ATTRIBUTES = {
      :email => 'E-mail address',
      :accept_tos => 'Terms of service',
      :login => 'Username'
  }

  PROFILE_IMAGE_SIZES = [:main_picture, :small_picture]

  #========== VALIDATORS

  validates_presence_of       :login, :email, :unless => :openid?
  validates_acceptance_of     :accept_tos,                 :unless => :openid?
  validates_presence_of       :password,                   :if => :password_required?
  validates_length_of         :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of   :password,                   :if => :password_required?
  validates_length_of         :login,    :within => 3..40, :unless => :openid?
  validates_length_of         :email,    :within => 3..100, :unless => :openid?
  validates_format_of         :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, :message => 'is invalid'
  validates_format_of         :login, :with => /\A\w+\z/, :message => 'can only contain letters and numbers (no spaces).'
  validates_uniqueness_of     :login,        :case_sensitive => false, :allow_nil => true
  validates_uniqueness_of     :email,        :case_sensitive => false, :allow_nil => true
  validates_uniqueness_of     :identity_url, :case_sensitive => false, :allow_nil => true, :allow_blank => true

  #========== FILTERS

  after_validation -> { merge_validation_errors_with(:user_profile) }

  # sets all privacy setting to default values
  after_create -> { set_all_default_privacies(UserPrivacyOptionItem::DEFAULT_PRIVACY) }

  update_email_subscription_when_changed :self, [:email]

  # on ban or delete, clean up this user's associations with various parts of the site
  after_save -> {
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
  }, :if => -> { (is_banned? || is_deactivated?) && status_changed? }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :representative,
             :class_name => 'Person', :foreign_key => 'representative_id'
  belongs_to :user_role

  #----- HAS_ONE

  has_one  :user_profile
  has_one  :user_privacy_options
  has_one  :user_options
  has_one  :user_mailing_list
  has_one  :twitter_config
  has_one  :latest_ip_address,
           :class_name => 'UserIpAddress', :order => 'created_at DESC'
  has_one  :watch_dog
  has_one  :political_notebook,
           :dependent => :destroy
  has_one  :user_notification_options

  #----- HAS_MANY

  has_many :owned_groups,
           :class_name => 'Group'
  has_many :group_members
  has_many :groups,
           :through => :group_members
  has_many :group_invites
  has_many :api_hits
  has_many :comments,
           :dependent => :destroy
  has_many :commentary_ratings
  has_many :comment_scores
  has_many :user_ip_addresses
  has_many :friends
  has_many :friend_invites,
           :foreign_key => 'inviter_id'
  has_many :fans, -> { where(confirmed: false) },
           :class_name => 'Friend', :foreign_key => 'friend_id'
  has_many :person_approvals
  has_many :bookmarks,
           :dependent => :destroy
  has_many :senator_bookmarks, -> { includes([:person => :roles]).where('roles.role_type = ? and roles.startdate < ? and roles.enddate > ?', 'sen', Time.now, Time.now) },
           :class_name => 'Bookmark', :foreign_key => 'user_id'
  has_many :representative_bookmarks, -> { includes([:person => :roles]).where('roles.role_type = ? and roles.startdate < ? and roles.enddate > ?', 'rep', Time.now, Time.now )},
           :class_name => 'Bookmark', :foreign_key => 'user_id'
  has_many :legislator_bookmarks, -> { includes([:person => :roles]).where('roles.role_type in(?) and roles.startdate < ? and roles.enddate > ?', ["sen", "rep"], Time.now, Time.now)},
           :class_name => 'Bookmark', :foreign_key => 'user_id'
  has_many :bill_bookmarks, -> { where('bookmarks.bookmarkable_type = ?', 'Bill') },
           :class_name => 'Bookmark', :foreign_key => 'user_id'
  has_many :issue_bookmarks, -> {  where('bookmarks.bookmarkable_type = ?', 'Subject') },
           :class_name => 'Bookmark', :foreign_key => 'user_id'
  has_many :committee_bookmarks, -> { where('bookmarks.bookmarkable_type = ?', 'Committee') },
           :class_name => 'Bookmark', :foreign_key => 'user_id'
  has_many :watched_districts,
           :class_name => "WatchDog"
  has_many :bill_votes
  # TODO: The original implementation included the number of people who have bookmarked the bill, which should be done differently
  has_many :bookmarked_bills, -> { order('bookmarks.created_at DESC') },
           :class_name => 'Bill', :through => :bookmarks, :source => :bill
  has_many :bills_voted_on, -> { order('bill_votes.created_at DESC') },
           :class_name => 'Bill', :through => :bill_votes, :source => :bill
  # Support = 0 for support, 1 for oppose. Not even kidding.
  has_many :bills_supported, -> { where('bill_votes.support = ?','0').order('bill_votes.created_at DESC') },
           :class_name => 'Bill', :through => :bill_votes, :source => :bill
  has_many :bills_opposed, -> { where('bill_votes.support = ?','1').order('bill_votes.created_at DESC') },
           :class_name => 'Bill', :through => :bill_votes, :source => :bill
  has_many :bookmarked_people, -> { where('bookmarks.bookmarkable_type = ?','Person').order('bookmarks.created_at DESC') },
           :class_name => 'Person', :through => :bookmarks, :source => :person
  has_many :bookmarked_issues, -> { where('bookmarks.bookmarkable_type = ?','Subject').order('bookmarks.created_at DESC') },
           :class_name => 'Subject', :through => :bookmarks, :source => :subject
  has_many :bookmarked_committees, -> { where('bookmarks.bookmarkable_type = ?','Committee').order('bookmarks.created_at DESC') },
           :class_name => 'Committee', :through => :bookmarks, :source => :committee
  has_many :user_warnings
  has_many :notebook_items,
           :through => :political_notebook
  has_many :contact_congress_letters
  has_many :notification_aggregates, -> { includes(:activities) },
           :dependent => :destroy
  has_many :user_notification_option_items, -> { joins(:activity_option) },
           :through => :user_notification_options
  has_many :user_privacy_option_items,
           :dependent => :destroy

  #========== ALIASES

  alias_attribute :username, :login

  # These are just here for some consistency in naming patterns
  alias_method :voted_bills, :bills_voted_on
  alias_method :supported_bills, :bills_supported
  alias_method :opposed_bills, :bills_opposed
  alias_method :notification_options, :user_notification_options
  alias_method :notification_option_items, :user_notification_option_items

  #========== SCOPES

  scope :for_state, lambda {|state| where('state = ?', state.upcase) }
  scope :for_district, lambda {|state, district| for_state(state).where('district = ?', district.to_i) }
  scope :active, lambda { where('previous_login_date >= ?', 1.months.ago) }
  scope :inactive, lambda { where('previous_login_date < ? OR previous_login_date IS NULL', 3.months.ago)}
  scope :tracking_bill, lambda {|bill| includes(:bookmarked_bills).where('bills.id' => bill.id) }
  scope :voted_on_bill, lambda {|bill| includes(:bills_voted_on).where('bills.id' => bill.id) }
  scope :supporting_bill, lambda {|bill| includes(:bills_supported).where('bills.id' => bill.id) }
  scope :opposing_bill, lambda {|bill| includes(:bills_opposed).where('bills.id' => bill.id) }
  scope :supporting_person, lambda{|person| includes(:person_approvals).where('person_approvals.person_id' => person.id).where('rating > 5')}
  scope :opposing_person, lambda{|person| includes(:person_approvals).where('person_approvals.person_id' => person.id).where('rating > 5')}
  scope :ranking_person, lambda{|person| includes(:person_approvals).where('person_approvals.person_id' => person.id).where('rating is not null')}
  scope :tracking_person, lambda {|person| includes(:bookmarked_people).where('people.id' => person.id) }
  scope :tracking_issue, lambda {|subject| includes(:bookmarked_issues).where('subjects.id' => subject.id) }
  scope :tracking_committee, lambda {|committee| includes(:bookmarked_committees).where('committees.id' => committee.id) }
  scope :mypn_spammers, lambda{includes(:political_notebook => [:notebook_items]).where('notebook_items.spam = ?', true).order('users.login ASC')}

  # These are LoD helpers that just pass on AR relations from Person
  def bookmarked_senators; bookmarked_people.sen; end
  def bookmarked_representatives; bookmarked_people.rep; end

  #========== ACCESSORS

  accepts_nested_attributes_for :user_privacy_options, :user_profile, :user_options

  # Note that some attrs are defined in authable_model
  # accept_tos and email_confirmation are unpersisted accessors for validation only

  attr_accessor :accept_tos, :email_confirmation, :suppress_activation_email

  #========== SERIALIZERS

  serialize :possible_states, Array
  serialize :possible_districts, Array

  #========== DELEGATERS

  delegate :zipcode=, :to => :user_profile
  delegate :street_address=, :to => :user_profile
  delegate :street_address_2=, :to => :user_profile
  delegate :city=, :to => :user_profile

  %w(zipcode zip_four street_address street_address_2 small_picture main_picture
     first_name last_name full_name website about city coordinates location address mobile_phone).each do |prop|
    delegate prop.to_sym, to: :user_profile
  end

  %w(comment_threshold opencongress_mail partner_mail sms_notifications email_notifications feed_key).each do |prop|
    delegate prop.to_sym, :to => :user_options
  end

  %w(name email zipcode location profile actions tracked_items
     friends political_notebook watchdog).each do |prop|
    delegate prop.to_sym, :to => :user_privacy_options, :prefix => :share
  end

  delegate :privatize!,               :to => :user_privacy_options
  delegate :change_location!,         :to => :user_profile
  delegate :mailing_address,          :to => :user_profile
  delegate :mailing_address_as_hash,  :to => :user_profile

  # create related class instances on first access
  %w(user_profile user_options user_privacy_options).each do |meth|
    alias_method(:"_#{meth}", meth.to_sym)
    define_method(meth.to_sym){ send(:"_#{meth}") || send(:"build_#{meth}")}
  end

  #========== METHODS

  #----- CLASS

  # Generate a random hex string of an input length
  #
  # @return [String] hex string of input length
  def self.random_password(length=40)
    return SecureRandom.hex(length/2)
  end

  def self.login_stub_for_profile(profile)
    address = Mail::Address.new(profile.email)
    # remove any non-alphnumeric character and everything following it
    stub = address.local.sub(/[^a-z0-9].*$/i, '')
    stub = "#{profile.first_name}#{profile.last_name.first}" if stub.length < 5
    stub = 'newuser' if stub.length < 5
    return stub
  end

  def self.unused_login(stub, max_attempts=100)
    candidate = stub
    max_attempts.times do
      user = User.find_by_login(candidate)
      return candidate if user.nil?
      candidate = stub + SecureRandom.random_number(9999).to_s(10)
    end
    return nil
  end

  def self.generate_for_profile(profile, options=HashWithIndifferentAccess.new)
    begin
      ActiveRecord::Base.transaction do
        login = unused_login(login_stub_for_profile(profile))
        user = User.new(:login => login,
                        :email => profile.email,
                        :password => random_password,
                        :accepted_tos_at => profile.accept_tos && Time.now || nil,
                        :state => profile.state
        )
        # Authable#make_password_reset_code is protected and that's probably not
        # a bad thing. This, however is a kludge. FIXME.
        user.send(:make_password_reset_code)

        user.suppress_activation_email = options[:suppress_activation_email]
        user.save!
        user = User.find_by_login(login)

        attributes = profile.attributes_hash.slice(:first_name, :last_name, :mobile_phone, :street_address, :street_address_2, :city, :zipcode, :zip_four)
        if user.user_profile.id.nil?
          uprof = UserProfile.new(attributes)
          uprof.user = user
          uprof.save!
        else
          user.user_profile.update_attributes(attributes)
        end

        return user
      end
    rescue ActiveRecord::RecordInvalid => e
      e.record.errors[:login].include?('has already been taken') ? retry : raise
    end
  end

  def self.highest_rated_commenters
    cs = CommentScore.calculate(:count, :score, :include => "comment", :group => "comments.user_id", :order => "count_score DESC").collect {|p| p[1] > 3 && p[0] != nil ? p[0] : nil}.compact
    CommentScore.calculate(:avg, :score, :include => "comment", :group => "comments.user_id", :conditions => ["comments.user_id in (?)", cs], :order => "avg_score DESC").each do |k|
      puts "#{User.find_by_id(k[0]).login} - Average Rating: #{k[1]}"
    end
  end

  def self.find_all_by_ip(address)
    includes(:user_ip_addresses).where('user_ip_addresses.addr = ?', UserIpAddress.int_form(address))
  end

  def self.find_by_feed_key_option(key)
    includes(:user_options).where('user_options.feed_key = ?', key).first
  end

  def self.fix_duplicate_users
    User.find_by_sql('select login, COUNT(*) as r1_tally FROM users GROUP BY login HAVING COUNT(*) > 1 ORDER BY r1_tally desc;').each do |k|
      puts k.login
      number = k.r1_tally.to_i
      User.where(login: k.login).order('created_at DESC').each do |j|
        number = number - 1
        j.destroy unless number == 1
      end
    end

    User.find_by_sql('select email, COUNT(*) as r1_tally FROM users GROUP BY email HAVING COUNT(*) > 1 ORDER BY r1_tally desc;').each do |k|
      puts k.email
      number = k.r1_tally.to_i
      User.where(email: k.email).order('created_at DESC')
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

  #----- INSTANCE

  public

  # Retrieves recent activity for the current user for a given timeframe
  #
  # @param limit [Integer] limit number of returned results
  # @param timeframe [Time] time back to consider recent
  # @param type [String] type of activity to query for
  # @return [Relation<PublicActivity::Activity>] activity of the user
  def recent_activity(limit=10, timeframe=7.days, type=nil)
    range = (Time.now - timeframe)..Time.now
    query = {created_at: range, owner_id: id, owner_type: 'User'}
    query[:trackable_type] = type if type.present?
    PublicActivity::Activity.where(query).limit(limit)
  end

  # Update user metadate to include last login time and log their IP
  #
  # @param ip_addr [String] string representation of IP address
  def update_login_metadate(ip_addr)
    update_attribute(:previous_login_date, last_login ? last_login : Time.now)
    update_attribute(:last_login, Time.now)
    user_ip_addresses.where(addr:UserIpAddress.int_form(ip_addr)).first_or_create
  end

  # Follows another user or confirms friendship if already being followed by user
  #
  # @param user [User] user to follow
  # @return [Boolean] true for success, false otherwise
  def follow(user)
    # already following the user so return false
    return false if Friend.where(user: self, friend: user).any?
    # check if already being followed by other user
    followed = Friend.where(user: user, friend: self).first
    # confirm if being followed, otherwise create one-way friend
    followed.present? ? followed.confirm! : Friend.create({user: self, friend: user, confirmed: false })
  end

  # Unfollows another user
  #
  # @param user [User] user to unfollow
  # @return [Boolean] true for success, false otherwise
  def unfollow(user)
    friend = Friend.where(user: self, friend: user).first
    friend.defriend if friend.present?
  end

  # Retrieves specific notification settings for a user
  #
  # @param key [String] activity key for specific settings, nil for all
  # @param bookmark [Bookmark] bookmark object for granular options, nil for all
  # @return [UserNotificationOptionItem] a user's notification settings
  def notification_option_item(key=nil, bookmark=nil)

    if key.present? and bookmark.present?
      noi = notification_option_items.where('activity_options.key = ? AND bookmark_id = ?', key, bookmark.id).last
    elsif key.present?
      noi = notification_option_items.where('activity_options.key = ?', key).last
    elsif bookmark.present?
      noi = notification_option_items.where('bookmark_id = ?', bookmark.id).last
    else
      noi = nil
    end

    # return notification option if it exists, fall back on unpersisted generic default otherwise
    noi.present? ? noi : UserNotificationOptionItem.default
  end

  # Sets all default privacy options to broad default values. Used when
  # user selects their default privacy settings.
  #
  # @param privacy [Symbol] privacy options - :public, :private, :friend
  def set_all_default_privacies(privacy=:private)
    UserPrivacyOptionItem.set_all_default_privacies_for(self, privacy)
  end

  def set_all_privacies(privacy)
    # TODO implement to set all current privacy settings to argument value
  end

  # Checks if user can view an input item and method
  #
  # @param item [PrivacyObject] object to show to viewer
  # @param method [String] method to determine privacy of
  # @return [Boolean] true if this user can view item & method, false otherwise
  def can_view?(item, method=nil)
    item.respond_to?(:has_privacy_settings?) ? item.can_show_to?(self, method) : true
  end

  # Checks if user can show a PrivacyObject (w/ method) to a viewing user
  #
  # @param viewer [User] viewing user
  # @param item [PrivacyObject] object to show to viewer
  # @param method [String] method to determine privacy of
  # @return [Boolean] true if this user can view, false otherwise
  def can_show_item_to?(viewer, item, method=nil)
    begin
      return false if item.user != self
      privacy_option_for({item:item, method:method}).can_show_to?(viewer)
    rescue
      false
    end
  end

  # Retrieves user's unseen notifications
  #
  # @return [Relation<AggregateNotification>] all unseen notifications
  def get_unseen_notifications
    notification_aggregates.where(click_count: 0)
  end

  def is_admin?
    user_role.can_administer_users
  end

  def has_state_and_district?
    state.present? and district.present?
  end

  def placeholder
    "placeholder"
  end

  def picture_path(size=:main)
    filename = send("#{size}_picture".to_sym)
    "users/#{filename}"
  end

  def profile_image_path(size)
    path_sym = PROFILE_IMAGE_SIZES[0]
    if size.present?
      size_sym = size.to_sym
      path_sym = size_sym if PROFILE_IMAGE_SIZES.include?(size_sym)
    end
    img_path = send(path_sym)
    return img_path ? "/images/users/#{img_path}" : 'anonymous.gif'
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

  def password_required?
    !openid? && !facebook_connect_user? && ((password_digest.blank? && crypted_password.blank?) || password.present?)
  end

  def openid?
    !identity_url.blank?
  end

  def facebook_connect_user?
    !facebook_uid.blank?
  end

  def should_receive_creation_email?
    !facebook_connect_user? && !suppress_activation_email
  end

  # Retrieves specific notification settings for behavior based
  # on specific item, type, and/or method
  #
  # @param args [Hash] arguments containing one or more of the following:
  #        item [PrivacyObject] object which includes the privacy_object module
  #        type [String] type of a PrivacyObject for generic privacy setting
  #        method [String] specific method or attribute privacy
  # @return [UserPrivacyOptionItem] privacy options (may construct temporary default)
  def privacy_option_for(args={item:nil,type:nil,method:nil})

    begin
      args.init_missing_keys(nil, :item, :type, :method)

      query = { :method => args[:method] }

      # check granular item instance first
      if args[:item].present?
        query[:privacy_object_type] = args[:item].class.name
        query[:privacy_object_id] = args[:item].id
        upoi = user_privacy_option_items.where(query).first
        return upoi unless upoi.nil?
      end

      # check general type next
      if args[:type].present? or args[:item].present?
        query[:privacy_object_type] = args[:type] || args[:item].class.name
        query[:privacy_object_id] = nil
        upoi = user_privacy_option_items.where(query).first
        return upoi unless upoi.nil?
      end

      # use default privacy if no privacy option found
      return UserPrivacyOptionItem.default(self, args)
    rescue
      UserPrivacyOptionItem.default(self, nil)
    end

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

  def attributes_protected_by_default
    []
  end

end
