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

class CommitteeName < OpenCongressModel

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :committee

end
