PublicActivity::Activity.class_eval do

  #========== FILTERS

  after_create :create_user_notifications

  #========== RELATIONS

  #----- HAS MANY

  has_many :notifications, :foreign_key => 'activities_id'

  #========== METHODS

  #----- INSTANCE

  # Creates notifications for users whenever a new activity is created.
  #
  # @return void
  def create_user_notifications

    # activity owner type inherits from Bookmarkable class --> multiple notification recipients
    if self.owner_type.constantize.superclass.name == 'Bookmarkable'
      Bookmark.where(bookmarkable_id:self.owner_id, bookmarkable_type:self.owner_type).each do |bm|
        # the delay method utilizes sidekiq to distribute the task of generating user notifications
        AggregateNotification.delay.create_from_activity(self.id, bm.user_id)
      end

    # activity type doesn't inherit from Bookmarkable class --> single recipient
    elsif self.recipient_id.present?
      AggregateNotification.create_from_activity(self.id, recipient.id)
    end

  end

  def action
    key.split('.').last
  end

end