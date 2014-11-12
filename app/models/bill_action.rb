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

  #----- BELONGS_TO

  belongs_to :bill

  #========== SCOPES

  scope :action_and_vote, -> (action_type, vote_type=nil) { where({:action_type => action_type}.merge(vote_type.nil? ? {} : {:vote_type => vote_type})) }

  #========== METHODS

  #----- CLASS

  #----- INSTANCE

  public

  def rss_date
    Time.at(self.date)
  end

  def display(title = self.bill.title_full_common)
    render 'bill_action/display', :title => title
  end

  def to_email_body
    render "notifications/bill_action/create/type/#{self.action_type}", :bill_action => self
  end
  
end