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

class ApiHit < ActiveRecord::Base
  belongs_to :user  
end
