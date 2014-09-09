# == Schema Information
#
# Table name: api_hits
#
#  id         :integer          not null, primary key
#  action     :string(255)
#  user_id    :integer
#  created_at :datetime
#  updated_at :datetime
#  ip         :string(50)
#

class ApiHit < OpenCongressModel
  belongs_to :user  
end
