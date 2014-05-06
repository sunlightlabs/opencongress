# == Schema Information
#
# Table name: actions
#
#  id               :integer          not null, primary key
#  action_type      :string(255)
#  date             :integer
#  datetime         :datetime
#  how              :string(255)
#  where            :string(255)
#  vote_type        :string(255)
#  result           :string(255)
#  bill_id          :integer
#  amendment_id     :integer
#  type             :string(255)
#  text             :text
#  roll_call_id     :integer
#  roll_call_number :integer
#  created_at       :datetime
#  govtrack_order   :integer
#  in_committee     :text
#  in_subcommittee  :text
#  ordinal_position :integer
#

class AmendmentAction < Action
  belongs_to :amendment
  
  def display
    "<h4>Amendment #{amendment.number}, #{amendment.purpose}, " +
      "#{amendment.status} as of #{amendment.status_datetime}</h4>" +
      "<p>#{amendment.description}</p>" +
      "<p>#{amendment.bill.display}</p>"
  end
end

