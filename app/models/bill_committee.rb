# == Schema Information
#
# Table name: bills_committees
#
#  id           :integer          not null, primary key
#  bill_id      :integer
#  committee_id :integer
#  activity     :string(255)
#

class BillCommittee < ActiveRecord::Base
  set_table_name 'bills_committees'
  validates_uniqueness_of :bill_id, :scope => :committee_id

  belongs_to :bill
  belongs_to :committee  
end
