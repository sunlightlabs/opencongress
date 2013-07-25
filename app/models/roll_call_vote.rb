require 'united_states'
class RollCallVote < ActiveRecord::Base  
  belongs_to :roll_call
  belongs_to :person
  
  after_create :recount_party_lines

  scope :for_state, lambda { |abbrev| {:include => :person, :conditions => {:people => {:state => abbrev} } } }
  scope :on_passage, lambda { includes(:roll_call).where("roll_calls.question ILIKE 'On Passage%' OR roll_calls.question ILIKE 'On Motion to Concur in Senate%' OR roll_calls.question ILIKE 'On Concurring%'") }
 
  scope :in_congress, lambda { |cong| includes(:roll_call).where(['date >= ? and date <= ?', UnitedStates::Congress.start_datetime(cong), UnitedStates::Congress.end_datetime(cong)]) }

  @@VOTE_FOR_SYMBOL = {
    "+" => "Aye",
    "-" => "Nay",
    "0" => "Abstain",
    "P" => "Present"
  }

  def self.for_duo (p1, p2)
    includes(:roll_call)
    .where(['(person_id = ? OR person_id = ?)', p1.id, p2.id])
    .group_by(&:roll_call_id)
    .values
    .select{|pair| pair.count == 2}
    .each{|pair| pair.sort_by!(&:person_id)}
  end
  
  def self.for_duo_in_congress (p1, p2, congress)
    includes(:roll_call)
    .where(['roll_calls.date >= ? AND roll_calls.date <= ? AND (person_id = ? OR person_id = ?)',
           UnitedStates::Congress.start_datetime(congress),
           UnitedStates::Congress.end_datetime(congress),
           p1.id, p2.id])
    .group_by(&:roll_call_id)
    .values
    .select{|pair| pair.count == 2}
    .each{|pair| pair.sort_by!(&:person_id)}
  end

  def atom_id
    "tag:opencongress.org,#{roll_call.date.strftime("%Y-%m-%d")}:/roll_call_vote/#{id}"
  end
  
  def to_s
    @@VOTE_FOR_SYMBOL[vote].nil? ? vote : @@VOTE_FOR_SYMBOL[vote]
  end
  
  def sort_date
    roll_call.date
  end
  
  def rss_date
    roll_call.date
  end
  
  # can't use a standard comparison for the next two methods because we don't want to count abstains
  def same_vote(other_vote)
    (((vote == "+") && (other_vote.vote == "+")) || ((vote == "-") && (other_vote.vote == "-")))
  end

  def different_vote(other_vote)
    (((vote == "+") && (other_vote.vote == "-")) || ((vote == "-") && (other_vote.vote == "+")))
  end
  
  def recount_party_lines
    self.roll_call.set_party_lines
  end
  
  def self.abstain_count
    RollCallVote.count(:all, :include => [{:roll_call => :bill}], :conditions => ["bills.session = ? AND roll_call_votes.vote = ?", Settings.default_congress, "0"], :group => "person_id").sort{|a,b| b[1]<=>a[1]}
  end
  
  def with_party?
    case self.person.party
    when 'Republican'
      if ( self.roll_call.republican_position == true && self.vote == '+' ) || ( self.roll_call.republican_position == false && self.vote == '-' )
        true
      else
        false
      end
    when 'Democrat'
      if ( self.roll_call.democratic_position == true && self.vote == '+' ) || ( self.roll_call.democratic_position == false && self.vote == '-' )
        true
      else
        false
      end
    else
      nil
    end
  end

  def is_affirmative?
    return ['Yea', 'Aye', '+'].include?(vote)
  end

  def is_negative?
    return ['No', 'Nay', '-'].include?(vote)
  end

  def is_present?
    return ['P', 'Present'].include?(vote)
  end

  def is_non_vote?
    return ['Not Voting', '0'].include?(vote)
  end 
end
