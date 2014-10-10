# == Schema Information
#
# Table name: user_notification_options
#
#  id                     :integer          not null, primary key
#  email_digest_frequency :string(255)
#  user_id                :integer
#  created_at             :datetime
#  updated_at             :datetime
#

class UserNotificationOptions < OpenCongressModel

  #========== FILTERS

  before_create -> { set_default_attributes_for_nil }

  #========== CONSTANTS

  DEFAULT_ATTRIBUTES = { email_digest_frequency: 'week' }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :user

  #----- HAS_MANY

  has_many :user_notification_option_items, :foreign_key => 'user_notification_option_id'
  has_many :activity_options, :through => :user_notification_option_items

  #========== METHODS

  #----- INSTANCE

end