# == Schema Information
#
# Table name: committee_stats
#
#  committee_id       :integer          not null, primary key
#  entered_top_viewed :datetime
#

class CommitteeStats < OpenCongressModel

  #========== VALIDATORS

  self.primary_key = :committee_id

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :committee

end