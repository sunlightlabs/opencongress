# == Schema Information
#
# Table name: industry_stats
#
#  sector_id          :integer          not null, primary key
#  entered_top_viewed :datetime
#

class IndustryStats < ActiveRecord::Base
  set_primary_key :sector_id
  
  belongs_to :sector
end
