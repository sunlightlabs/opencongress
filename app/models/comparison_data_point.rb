# == Schema Information
#
# Table name: comparison_data_points
#
#  id            :integer          not null, primary key
#  comparison_id :integer
#  comp_value    :integer
#  comp_indx     :integer
#  created_at    :datetime
#  updated_at    :datetime
#

class ComparisonDataPoint < ActiveRecord::Base
  belongs_to :comparison
end
