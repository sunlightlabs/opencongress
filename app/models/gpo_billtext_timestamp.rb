# == Schema Information
#
# Table name: gpo_billtext_timestamps
#
#  id         :integer          not null, primary key
#  session    :integer
#  bill_type  :string(255)
#  number     :integer
#  version    :string(255)
#  created_at :datetime
#

class GpoBilltextTimestamp < OpenCongressModel 
end
