# == Schema Information
#
# Table name: notifications
#
#  id                    :integer          not null, primary key
#  user_id               :integer
#  notifying_object_id   :integer
#  seen                  :integer
#  created_at            :datetime
#  updated_at            :datetime
#  notifying_object_type :string(255)
#

class Notification < OpenCongressModel
  belongs_to :notifying_object, polymorphic: true

  attr_accessible :user_id, :notifying_object_id, :notifying_object_type, :seen
end
