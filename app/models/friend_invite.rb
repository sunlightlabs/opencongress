# == Schema Information
#
# Table name: friend_invites
#
#  id            :integer          not null, primary key
#  inviter_id    :integer
#  invitee_email :string(255)
#  created_at    :datetime
#  invite_key    :string(255)
#

class FriendInvite < OpenCongressModel
  belongs_to :inviter, :class_name => "User", :foreign_key => :inviter_id
end
