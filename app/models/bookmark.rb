# == Schema Information
#
# Table name: bookmarks
#
#  id                :integer          not null, primary key
#  created_at        :datetime         not null
#  bookmarkable_type :string(15)       default(""), not null
#  bookmarkable_id   :integer          default(0), not null
#  user_id           :integer          default(0), not null
#

class Bookmark < OpenCongressModel

  #========== INCLUDES

  include PrivacyObject

  #========== VALIDATORS

  validates_uniqueness_of :bookmarkable_id, :scope => [:user_id, :bookmarkable_type]

  #========== RELATIONS

  #----- BELONGS TO

  belongs_to :bookmarkable, :polymorphic => true
  belongs_to :user # NOTE: Comments belong to a user

  with_options :foreign_key => 'bookmarkable_id' do |b|
    b.belongs_to :person, -> { includes :roles}
    b.belongs_to :bill
    b.belongs_to :subject
    b.belongs_to :committee
  end

  #========== SCOPES

  scope :bills, includes(:bill).where(:bookmarkable_type => 'Bill')
  scope :committees, includes(:committee).where(:bookmarkable_type => 'Committee')
  scope :people, includes(:person).where(:bookmarkable_type => 'Person')
  scope :subjects, includes(:subject).where(:bookmarkable_type => 'Subject')

  # NOTE: install the acts_as_taggable plugin if you want bookmarks to be tagged.
  acts_as_taggable

  #========== METHODS

  #----- CLASS

  # Find all bookmarks for a given user
  #
  # @param user [User] the user model to find all bookmarks for
  # @return [Relation<Bookmark>] the bookmarks associated with the user
  def self.find_bookmarks_by_user(user)
    where('user_id = ?', user.id).order('created_at DESC')
  end

  # Find a bookmarkable record by the type and id
  #
  # @param commentable_str [String] the class name as string to look up
  # @param commentable_id [Integer] the id of the commentable record
  # @return [Commentable]
  def self.find_bookmarkable(commentable_str, commentable_id)
    commentable_str.constantize.find(commentable_id)
  end

  # Find all bookmarks for a given user and person role
  #
  # @param user [User] the user model to find all bookmarks for
  # @param role [String] 'sen' or 'rep'
  # @return [Bookmark]
  def self.find_bookmarks_by_user_and_person_role(user,role)
    eager_load({:person => :roles}).where(:bookmarkable_type =>'Person',:user_id => user,'roles.role_type' => role)
  end

  # Find all bill bookmarks for a given user
  #
  # @param user [User] the user model to find all bill bookmarks for
  # @return [Relation<Bill>]
  def self.find_bookmarked_bills_by_user(user)
    where(user_id:user, bookmarkable_type: 'Bill')
  end

  #----- INSTANCE

  # Get all notifications for this bookmark
  #
  # @param seen [Integer] 0 for unseen, greater than 0 for numbers of times seen, nil for all
  # @return [Relation<Notification>] notifications for the user associated with this bookmark
  def notification_aggregates(seen=nil)
    ids = PublicActivity::Activity.where(owner_id:self.bookmarkable_id, owner_type:self.bookmarkable_type).collect{|a| a.id}
    NotificationAggregate.includes(:activities).where(user_id: self.user_id, click_count: seen.nil? ? 0..Float::INFINITY : seen, 'activities.id' => ids)
  end

end