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

class BillAction < Action

  #========== INCLUDES

  include PublicActivity::Model ; tracked owner: :bill, only: :create

  #========== RELATIONS

  belongs_to :bill

  #========== METHODS

  #----- INSTANCE

  def display
    "<h4>#{bill.title_full_common}</h4>"
  end

  def rss_date
    Time.at(self.date)
  end

  def to_email_body
    case self.action_type
      when 'action'
        "received the action: #{self.text.uncapitalize.strip_period}"
      when 'referral'
        "#{self.text.uncapitalize.strip_period}"
      when 'hearings'
        split = self.text.split('. ')
        "hearing in the #{split[0]}. #{split[2] if split.length > 2}"
      when 'calendar'
        split = self.text.split(' ')
        if split[0] == 'Committee'
          split = self.text.split('. ')
          "#{split[1].uncapitalize} in the #{split[0]}"
        else
          "#{self.text.uncapitalize.strip_period}"
        end
      when 'reported'
        "received a report in the #{self.text.strip_period}"
      when 'vote'
        "received vote action: #{self.text.uncapitalize.strip_period}"
      when 'topresident'
        "#{self.text.uncapitalize.strip_period}"
      when 'signed'
        'signed by the President'
      when 'enacted'
        "enacted and #{self.text.uncapitalize.strip_period}"
      when 'vote-aux'
        "received a #{self.text.uncapitalize.strip_period}"
      when 'vetoed'
        'vetoed by the President'
      else
        "received the action: #{self.text.uncapitalize.strip_period}"
    end
  end
  
end