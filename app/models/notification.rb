# == Schema Information
#
# Table name: notifications
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  seen          :integer
#  created_at    :datetime
#  updated_at    :datetime
#  activities_id :integer
#

class Notification < OpenCongressModel

  #========== CALLBACKS

  after_create -> { send_email_notification }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :activity, :class_name => 'PublicActivity::Activity', :foreign_key => 'activities_id'
  belongs_to :user

  alias :recipient :user

  #========== ACCESSORS

  attr_accessible :user_id, :activities_id, :seen

  #========== INSTANCE METHODS

  private

  def send_email_notification
    method = "#{activity.key.sub('.','_')}_notification".to_sym
    UserNotifier.send(method, self).deliver if UserNotifier.respond_to?(method)
  end

end