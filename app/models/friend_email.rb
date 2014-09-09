# == Schema Information
#
# Table name: friend_emails
#
#  id             :integer          not null, primary key
#  emailable_id   :integer          not null
#  emailable_type :string(255)
#  created_at     :datetime
#  ip_address     :string(255)
#

class FriendEmail < OpenCongressModel
  belongs_to :emailable, :polymorphic => true
end
