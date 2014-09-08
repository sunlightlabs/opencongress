# == Schema Information
#
# Table name: bill_fulltext
#
#  bill_id   :integer          primary key
#  fulltext  :text
#  fti_names :public.tsvector
#

class BillFulltext < OpenCongressModel

  self.primary_key = :bill_id
  self.table_name = :bill_fulltext
  
  belongs_to :bill
end
