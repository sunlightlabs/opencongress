# == Schema Information
#
# Table name: watch_dogs
#
#  id          :integer          not null, primary key
#  district_id :integer
#  user_id     :integer
#  is_active   :boolean
#  created_at  :datetime
#  updated_at  :datetime
#

class WatchDog < OpenCongressModel

  belongs_to :district
  belongs_to :user
  
  def self.recent_actions
    

  end
  
  def login_district
    self.user.login + " (#{district.district_state_text})"
  end

end
