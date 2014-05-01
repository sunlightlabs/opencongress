# == Schema Information
#
# Table name: comparisons
#
#  id            :integer          not null, primary key
#  type          :string(255)
#  congress      :integer
#  chamber       :string(255)
#  average_value :integer
#  created_at    :datetime
#  updated_at    :datetime
#

class RepDemComparison < Comparison
end
