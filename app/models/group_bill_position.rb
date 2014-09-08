# == Schema Information
#
# Table name: group_bill_positions
#
#  id         :integer          not null, primary key
#  group_id   :integer
#  bill_id    :integer
#  position   :string(255)
#  comment    :string(255)
#  permalink  :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class GroupBillPosition < OpenCongressModel
  belongs_to :group
  belongs_to :bill
  
  validates_presence_of :group_id
  validates_presence_of :bill_id
  validates_presence_of :position
end
