# == Schema Information
#
# Table name: committee_names
#
#  id           :integer          not null, primary key
#  committee_id :integer
#  name         :string(255)
#  session      :integer
#  created_at   :datetime
#  updated_at   :datetime
#

class CommitteeName < ActiveRecord::Base
  attr_accessible :name, :session

  belongs_to :committee
end
