# == Schema Information
#
# Table name: congress_chamber_committees
#
#  id                   :integer          not null, primary key
#  congress_chambers_id :integer
#  committees_id        :integer
#  created_at           :datetime
#  updated_at           :datetime
#

class CongressChamberCommittee < OpenCongressModel

end
