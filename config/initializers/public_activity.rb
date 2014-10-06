PublicActivity::Activity.class_eval do

  after_create :create_user_notifications

  has_many :notifications, :foreign_key => 'activities_id'

  # Creates notifications for users based on whether they're bookmarking the object
  # or being a recipient of an activity
  def create_user_notifications

    if self.owner_type.constantize.superclass.name == 'Bookmarkable'
      Bookmark.where(bookmarkable_id:self.owner_id, bookmarkable_type:self.owner_type).each do |bm|
        AggregateNotification.create_from_activity(self,bm.user_id)
      end

    elsif self.recipient_id.present?
      AggregateNotification.create_from_activity(self, recipient.id)
    end

  end

  def action
    key.split('.').last
  end

end