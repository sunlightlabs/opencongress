# == Schema Information
#
# Table name: notification_aggregates
#
#  id          :integer          not null, primary key
#  score       :integer          default(0)
#  hide        :integer          default(0)
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  click_count :integer          default(0)
#

class NotificationAggregate < OpenCongressModel

  #========== FILTERS

  # touched when new child notification item is created
  after_touch -> { NotificationDistributor.initiate_distribution(self) }

  #========== RELATIONS

  #----- HAS MANY

  has_many :notification_items, :dependent => :delete_all
  has_many :notification_distributors, :dependent => :destroy
  has_many :activities, :class_name => 'PublicActivity::Activity', :through => :notification_items

  #----- BELONGS TO

  belongs_to :user

  #========== ALIASES

  alias :recipient :user

  #========== METHODS

  #----- CLASS

  # Factory for aggregate notification creation for when public activity generates activity.
  #
  # @param activity_id [Integer] PublicActivity::Activity id value
  # @param user_id [Integer] User id value
  # @return [AggregateNotification, nil] an instance or nil
  def self.create_from_activity(activity_id, user_id)

    begin
      activity = PublicActivity::Activity.find(activity_id)
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound
      return nil
    end

    # check for whether this is a one-to-one notification or one-to-many
    na_query = activity.recipient.present? ?
               {'activities.key'=>activity.key, 'activities.recipient_id'=>user_id} :
               {'activities.key'=>activity.key, 'activities.owner_id'=>activity.owner_id, 'activities.owner_type'=>activity.owner_type}

    # TODO: optimize this with database indexes
    na = user.notification_aggregates.where(na_query).last

    # get bookmark for aggregate if it exists
    bookmark = na.present? ? na.bookmark : Bookmark.where(user_id: user_id,
                                                          bookmarkable_id: activity.owner_id,
                                                          bookmarkable_type: activity.owner_type).last
    # get user's settings for this particular activity and bookmark if it exists
    na_options = user.notification_option_item(activity.key, bookmark)
    # create new aggregate notification if user settings calls for it
    na = NotificationAggregate.create(user_id:user_id, updated_at: nil) if na_options.stale_aggregate?(na)
    # create notification item and associated with aggregate notification
    NotificationItem.create(activities_id:activity.id, notification_aggregate_id:na.id)

    return na

  end

  #----- INSTANCE

  public

  def activity_trackable
    activities.first.trackable if activities.any?
  end

  def activity_owner
    activities.first.owner if activities.any?
  end

  def activity_key
    activities.first.key if activities.any?
  end

  def bookmark
    ao = activity_owner
    Bookmark.where(bookmarkable_id:ao.id, bookmarkable_type: ao.class.name, user_id: self.user_id).first
  end

end