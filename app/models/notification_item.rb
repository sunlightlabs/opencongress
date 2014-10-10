# == Schema Information
#
# Table name: notification_items
#
#  id                        :integer          not null, primary key
#  notification_aggregate_id :integer
#  activities_id             :integer
#  created_at                :datetime
#  updated_at                :datetime
#

class NotificationItem < OpenCongressModel

  #========== VALIDATORS

  validates_presence_of :notification_aggregate, :activity

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :activity, :class_name => 'PublicActivity::Activity', :foreign_key => 'activities_id'
  belongs_to :notification_aggregate, touch:true

  #========== METHODS

  #----- CLASS

  #----- INSTANCE

end