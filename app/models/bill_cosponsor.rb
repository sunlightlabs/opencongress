# == Schema Information
#
# Table name: bills_cosponsors
#
#  id             :integer          not null, primary key
#  person_id      :integer
#  bill_id        :integer
#  date_added     :date
#  date_withdrawn :date
#

class BillCosponsor < OpenCongressModel

  include NotifyingObject

  self.table_name = :bills_cosponsors

  belongs_to :person  
  belongs_to :bill
end
