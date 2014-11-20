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


  #========== RELATIONS

  belongs_to :previous_action,
             :class_name => 'UserCtaTracker'

  #========== METHODS

  #----- INSTANCE

  public

  def user
    u = User.find(self.user_id) rescue user_id
  end

end