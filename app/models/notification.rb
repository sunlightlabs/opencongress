# == Schema Information
#
# Table name: notifications
#
#  id                        :integer          not null, primary key
#  created_at                :datetime
#  updated_at                :datetime
#  activities_id             :integer
#  aggregate_notification_id :integer
#

class Notification < OpenCongressModel

  #========== CALLBACKS

  #========== VALIDATORS

  validates_presence_of :aggregate_notification

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :activity, :class_name => 'PublicActivity::Activity', :foreign_key => 'activities_id'
  belongs_to :aggregate_notification

  #========== ACCESSORS

  #========== CLASS METHODS

  #========== INSTANCE METHODS

  public

  def activity_option
    ActivityOption.where(key:activity.key).first
  end

  private

end