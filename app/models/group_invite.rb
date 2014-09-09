# == Schema Information
#
# Table name: group_invites
#
#  id         :integer          not null, primary key
#  group_id   :integer
#  user_id    :integer
#  email      :string(255)
#  key        :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class GroupInvite < OpenCongressModel
  belongs_to :group
  belongs_to :user
  
  attr_accessor :invite_string
end
