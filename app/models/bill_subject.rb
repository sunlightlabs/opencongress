# == Schema Information
#
# Table name: bill_subjects
#
#  id         :integer          not null, primary key
#  bill_id    :integer
#  subject_id :integer
#

class BillSubject < OpenCongressModel
  validates_uniqueness_of :subject_id, :scope => :bill_id
  validates_uniqueness_of :bill_id, :scope => :subject_id
  validates_associated :bill, :subject 

  belongs_to :bill
  belongs_to :subject
end
