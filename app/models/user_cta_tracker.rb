# == Schema Information
#
# Table name: user_cta_trackers
#
#  id                 :integer          not null, primary key
#  user_id            :integer
#  previous_action_id :integer
#  url_path           :text
#  controller         :string(255)
#  method             :string(255)
#  params             :text
#  created_at         :datetime
#

class UserCtaTracker < OpenCongressModel

  #========== CONSTANTS

  LAST_ACTION_THRESHOLD = 3600 # seconds

  #========== RELATIONS

  belongs_to :previous_action,
             :class_name => 'UserCtaTracker'

  belongs_to :user

  #========== SERIALIZERS

  serialize :params, Hash

  #========== METHODS

  #----- INSTANCE

  public

  def user
    u = User.find(self.user_id) rescue user_id
  end

end