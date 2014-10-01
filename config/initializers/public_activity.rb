PublicActivity::Activity.class_eval do

  after_create :send_user_notifications

  has_many :notifications, :foreign_key => 'activities_id'

  # Creates notifications for users based on whether they're bookmarking the object
  # or being a recipient of an activity
  def send_user_notifications

    if self.owner_type.constantize.superclass.name == 'Bookmarkable'
      Bookmark.where(bookmarkable_id: self.owner_id, bookmarkable_type:self.owner_type).each do |bm|
        Notification.create(activities_id:self.id, user_id:bm.user_id, seen: 0)
      end

    elsif self.recipient_id.present?
      Notification.create(activities_id:self.id, user_id:recipient.id, seen: 0)
    end

  end

  def action
    key.split('.').last
  end

end