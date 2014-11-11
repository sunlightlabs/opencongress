# == Schema Information
#
# Table name: congress_chamber_people
#
#  id                   :integer          not null, primary key
#  congress_chambers_id :integer
#  people_id            :integer
#  created_at           :datetime
#  updated_at           :datetime
#

class CongressChamberPeople < OpenCongressModel

end
