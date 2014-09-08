# == Schema Information
#
# Table name: bill_stats
#
#  bill_id            :integer          not null, primary key
#  entered_top_viewed :datetime
#  entered_top_news   :datetime
#  entered_top_blog   :datetime
#

class BillStats < OpenCongressModel
  set_primary_key :bill_id
  
  belongs_to :bill
end
