# == Schema Information
#
# Table name: activity_options
#
#  id         :integer          not null, primary key
#  key        :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class ActivityOption < OpenCongressModel

  validates_uniqueness_of :key, :case_sensitive => true, :allow_nil => false

  has_many :activities, :class_name => 'PublicActivity::Activity', :primary_key => 'key', :foreign_key => 'key'
  has_many :user_notification_settings, :dependent => :destroy

end
