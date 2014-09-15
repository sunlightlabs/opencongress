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
require_dependency 'notifying_object'

class Action < OpenCongressModel
  include Comparable
  include NotifyingObject
 
  validates_presence_of :type

  # has_one :roll # votes?
  has_many :refers
  
  belongs_to :bill
  belongs_to :amendment

  belongs_to :roll_call
  
  has_many :action_references
  
  ACTIVITY_PERIODS = ["Today", "Yesterday", "Within a week", "Recently"]
  def self.classify_by_date(actions)
    def self.today(d)
      d > Time.new.at_beginning_of_day
    end
    
    def self.yesterday(d)
      d > 1.day.ago.at_beginning_of_day
    end
    
    def self.a_week(d)
      # d > 7.days.ago temp removal to find data to test with
      d > 7.days.ago
    end

    def self.a_month(d)
      # d > 1.month1.ago temp removal to find data to test with
      d > 1.months.ago
    end

    # Bin the actions by date using categories of today, this
    # week and older.
    h = {}
    ACTIVITY_PERIODS.each {|e| h[e] = []}
    h.each {|wh| wh = actions.find(:all) {|a| a.datetime > Time.new.yesterday } }
    actions.find(:all) do |a|
      today(a.datetime) ? h[ACTIVITY_PERIODS[0]] << a : true
    end.find(:all) do |a|
      yesterday(a.datetime) ? h[ACTIVITY_PERIODS[1]] << a : true
    end.find(:all) do |a|
      a_week(a.datetime) ? h[ACTIVITY_PERIODS[2]] << a : true
    end.find(:all) do |a|
      a_month(a.datetime) ? h[ACTIVITY_PERIODS[3]] << a : true
    end
    h
  end

  def to_s
    # Handle all kinds of actions:
    # In status, vote and vote2 can be present and are equivalent to a vote
    # action with matching type which has a text field too, and possible references.
    # 
    # actions element children:
    # 
    # action: date; datetime; text; optional references.
    # introduced: date, datetime.
    # vote: date, datetime, where, type, result, how, suspension, text, references, roll.
    # calendar: date, datetime, text, optional under, optional number, optional calendar.
    # topresident: date, datetime, text.
    # signed: date, datetime, text.
    # enacted: number, date, datetime, type, text.
    # vetoed: date, datetime, text.
    # 
    # under (attr): e.g. "General Orders".
    # number (attr): Congress number '-' Bill number.
    # text (elel): a descriptive string.
    # date (attr): UNIX date time.
    # datetime (attr): date or date and time.
    # reference (elem): label, ref
    # label (attr): 'text' or 'consideration'
    # ref (attr): e.g. CR S9200-9201, CR H7655 (a reference to one or more records in the CR)
    # suspension (attr): 1 or 0.
    # where (attr): 's' (Senate), 'h' (House)
    # result (attr): 'pass', 'fail'
    # how (attr): "roll" - implying roll attr, or "by Unanimous Consent", "by voice vote".
    # roll - roll id or "".
    # type (enacted attr): 'public'
    # type (vote attr): 'vote2', 'vote', 'override'.
    # case action_type.to_sym
    # when :action then action_to_s
    # when :introduced then introduced_to_s
    # when :vote then vote_to_s
    # when :calendar then calendar_to_s
    # when :topresident then topresident_to_s
    # when :signed then signed_to_s
    # when :enacted then enacted_to_s
    # when :vetoed then vetoed_to_s
    # else
    #   "Unknown action"
    # end
    if text.blank?
      if action_type == 'introduced'
        "Introduced in #{self.bill.chamber.capitalize}"
      else
        ""
      end
    else
      text
    end
  end

  def formatted_date
    if datetime.nil? and date.nil?
      ""
    elsif datetime.nil?
      Time.at(date).strftime("%b %d, %Y")
    else
      datetime.strftime("%b %d, %Y")
    end
  end

  def formatted_date_short
    if datetime.nil? and date.nil?
      ""
    elsif datetime.nil?
      Time.at(date).strftime("%b ") + Time.at(date).day.ordinalize    
    else
      datetime.strftime("%b ") + datetime.day.ordinalize
    end
  end

  def date_std
    datetime.strftime('%b %d, %Y')
  end
  
  def rss_date
    Time.at(self.date)
  end
  
  def atom_id
    "tag:opencongress.org,#{datetime.strftime("%Y-%m-%d")}:/action/#{id}"
  end
  
  private
  def action_to_s
    "#{self.date_std}: #{self.text} " + self.refers.join(' ')
  end
  
  def introduced_to_s
    "Introduced on #{self.date_std}."
  end

  def vote_to_s
    # vote: date, datetime, where, result, how, suspension, text, references, roll.
    "#{self.result == 'pass' ? 'Passed' : 'Failed'} #{self.how} in the " +
    "#{self.where == 's' ? 'Senate' : 'House'} on #{self.date_std}. #{self.text}"
  end
  
  def calendar_to_s
    "Added to calendar on #{self.date_std}: #{self.text}."
  end

  def topresident_to_s
    "#{self.date_std}. #{self.text}"
  end
  
  def signed_to_s
    "Signed on #{self.date_std}."
  end

  def enacted_to_s
    "Enacted on #{self.date_std}. #{self.text}"
  end

  def vetoed_to_s
    "Vetoed on #{self.date_std}. #{self.text}."
  end
  
  def <=>(another_action)
    if self.action_type == 'enacted'
      -1
    elsif self.action_type == 'vote' and self.vote_type == 'override'
      -1
    elsif self.action_type == 'signed'
      -1
    elsif self.action_type == 'vetoed'
      -1
    elsif self.action_type == 'topresident'
      -1
    else
      if (Date.parse(date_std) > Date.parse(another_action.date_std))
        -1
      elsif (Date.parse(date_std) < Date.parse(another_action.date_std))
        1
      else
        another_action.id <=> id
      end
    end
  end
  
end
