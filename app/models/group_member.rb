# == Schema Information
#
# Table name: group_members
#
#  id                   :integer          not null, primary key
#  group_id             :integer
#  user_id              :integer
#  status               :string(255)
#  receive_owner_emails :boolean          default(TRUE)
#  last_view            :datetime
#  created_at           :datetime
#  updated_at           :datetime
#

class GroupMember < OpenCongressModel
  belongs_to :group
  belongs_to :user
end
