# == Schema Information
#
# Table name: talking_points
#
#  id                      :integer          not null, primary key
#  talking_pointable_id    :integer
#  talking_pointable_type  :string(255)
#  talking_point           :text
#  created_at              :datetime
#  updated_at              :datetime
#  include_in_message_body :boolean          default(FALSE)
#

class TalkingPoint < ActiveRecord::Base
  belongs_to :talking_pointable, :polymorphic => true
end
