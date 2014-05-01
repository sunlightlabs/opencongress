# == Schema Information
#
# Table name: committee_stats
#
#  committee_id       :integer          not null, primary key
#  entered_top_viewed :datetime
#

class CommitteeStats < ActiveRecord::Base
  set_primary_key :committee_id
  
  belongs_to :committee
end
