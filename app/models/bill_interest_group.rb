# == Schema Information
#
# Table name: bill_interest_groups
#
#  id                    :integer          not null, primary key
#  bill_id               :integer          not null
#  crp_interest_group_id :integer          not null
#  disposition           :string(255)
#

class BillInterestGroup < OpenCongressModel  
  belongs_to :bill
  belongs_to :crp_interest_group
end
