# == Schema Information
#
# Table name: hot_bill_categories
#
#  id   :integer          not null, primary key
#  name :string(255)
#

class HotBillCategory < OpenCongressModel  
  has_many :bills
  has_many :notebook_items
end
