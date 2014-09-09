# == Schema Information
#
# Table name: pvs_category_mappings
#
#  id                         :integer          not null, primary key
#  pvs_category_id            :integer
#  pvs_category_mappable_id   :integer
#  pvs_category_mappable_type :string(255)
#

class PvsCategoryMapping < OpenCongressModel  
  belongs_to :pvs_category
  belongs_to :pvs_category_mappable, :polymorphic => true
  
  def to_s
    out = pvs_category.name
    mappable = pvs_category_mappable
    
    case mappable
    when Subject
      out += " --> Issue: #{mappable.term}"
    when CrpIndustry
      out += " --> CrpIndustry: #{mappable.name}"
    when CrpSector
      out += " --> CrpSector: #{mappable.name}"
    end
    return out
  end
end
