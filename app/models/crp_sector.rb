# == Schema Information
#
# Table name: crp_sectors
#
#  id           :integer          not null, primary key
#  name         :string(255)      not null
#  display_name :string(255)
#

class CrpSector < OpenCongressModel
  has_many :crp_industries, :order => 'name'
  
  has_many :pvs_category_mappings, :as => :pvs_category_mappable
  has_many :pvs_categories, :through => :pvs_category_mappings
end
