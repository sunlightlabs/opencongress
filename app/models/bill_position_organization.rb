# == Schema Information
#
# Table name: bill_position_organizations
#
#  id                       :integer          not null, primary key
#  bill_id                  :integer          not null
#  maplight_organization_id :integer          not null
#  name                     :string(255)
#  disposition              :string(255)
#  citation                 :text
#

class BillPositionOrganization < OpenCongressModel
  belongs_to :bill
end
