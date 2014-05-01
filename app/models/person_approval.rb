# == Schema Information
#
# Table name: person_approvals
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  rating     :integer
#  person_id  :integer
#  created_at :datetime
#  update_at  :datetime
#

#
# Model for end-user approval ratings of congresspeople
#
class PersonApproval < ActiveRecord::Base

  belongs_to :person
  belongs_to :user

end
