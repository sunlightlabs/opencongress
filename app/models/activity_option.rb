# == Schema Information
#
# Table name: activity_options
#
#  id              :integer          not null, primary key
#  key             :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  owner_model     :string(255)
#  trackable_model :string(255)
#

class ActivityOption < OpenCongressModel

  #========== VALIDATORS

  validates_uniqueness_of :key, :case_sensitive => true, :allow_nil => false
  validates_presence_of :owner_model, :trackable_model

  #========== RELATIONS

  #----- HAS_MANY

  has_many :activities, :class_name => 'PublicActivity::Activity', :primary_key => 'key', :foreign_key => 'key'
  has_many :user_notification_option_items, :dependent => :destroy

end