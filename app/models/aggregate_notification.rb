# == Schema Information
#
# Table name: aggregate_notifications
#
#  id          :integer          not null, primary key
#  click_count :integer
#  score       :integer
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#

class AggregateNotification < OpenCongressModel

  has_many :notifications
  has_many :activities, :class_name => 'PublicActivity::Activity', :through => :notifications
  belongs_to :user

  alias :recipient :user

  attr_accessible :user_id, :click_count, :score

  def self.create_from_activity(activity, user_id)

    # TODO: optimize this with database indexes
    an = User.find(user_id).aggregate_notifications
    .joins(:notifications,:activities)
    .where('activities.owner_id'=>activity.owner_id, 'activities.owner_type' => activity.owner_type, 'activities.key' => activity.key ).last

    an = AggregateNotification.create(user_id:user_id) if an.nil?

    Notification.create(activities_id:activity.id,aggregate_notification_id:an.id)

    an.email_notification if an.email_conditions_met?
  end

  def activity_owner
    activities.first.owner if activities.any?
  end

  def activity_key
    activities.first.key if activities.any?
  end

  def child_notification_created
    email_notification
  end

  def email_notification
    UserNotifier.setup_email(self).deliver
  end

  def email_conditions_met?
    usn = user.notification_settings(activity_key)

    return true if notifications.count >= usn.threshold
    # condition 2...
    # condition 3...
    # condition 4...

    return false

  end

end
