# == Schema Information
#
# Table name: roll_call_votes
#
#  id           :integer          not null, primary key
#  vote         :string(255)
#  roll_call_id :integer
#  person_id    :integer
#

require 'united_states'

class RollCallVote < OpenCongressModel

  #========== CLASS VARIABLES

  @@VOTE_FOR_SYMBOL = {
      '+' => 'Aye',
      '-' => 'Nay',
      '0' => 'Abstain',
      'P' => 'Present'
  }

  #========== CONSTANTS

  AFFIRMATIVE_VALUES = %W(Aye Yea +)
  NEGATIVE_VALUES    = %W(Nay No -)
  PRESENT_VALUES     = %W(Present P)
  ABSTAIN_VALUES     = ['Not Voting', '0']

  #========== FILTERS

  after_create :recount_party_lines

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :roll_call
  belongs_to :person

  #========== SCOPES

  scope :for_state, lambda {|abbrev| includes(:person).where(:person => {:state => abbrev}) }  # {:include => :person, :conditions => {:people => {:state => abbrev} } } }
  scope :on_passage, lambda { includes(:roll_call).where("roll_calls.question ILIKE 'On Passage%' OR roll_calls.question ILIKE 'On Motion to Concur in Senate%' OR roll_calls.question ILIKE 'On Concurring%'") }
  scope :in_congress, lambda { |cong| includes(:roll_call).where(['date >= ? and date <= ?', UnitedStates::Congress.start_datetime(cong), UnitedStates::Congress.end_datetime(cong)]) }

  scope :democrats, -> { includes(:person).order('people.lastname ASC').where('people.party = ?','Democrat') }
  scope :republicans, -> { includes(:person).order('people.lastname ASC').where('people.party = ?','Republican') }
  scope :independents, -> { includes(:person).order('people.lastname ASC').where('people.party NOT IN (?)', %W(Democrat Republican)) }

  scope :ayes, -> { where('vote IN(?)', AFFIRMATIVE_VALUES) }
  scope :nays, -> { where('vote IN(?)', NEGATIVE_VALUES) }
  scope :presents, -> { where('vote IN(?)', PRESENT_VALUES) }
  scope :abstains, -> { where('vote IN(?)', ABSTAIN_VALUES) }

  #========== METHODS

  #----- CLASS

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

  def self.abstain_count(chamber = nil, congress = Settings.default_congress)
    cache_key = 'roll_call_vote_abstain_by_person_table'
    Rails.cache.fetch(cache_key) do
      # TODO: joining to roles table isn't working so grabbing IDs first. Still a step up from before...
      rcv = chamber.nil? ? RollCallVote : RollCallVote.where(:person_id => (chamber.downcase == 'senate' ? Person.sen : Person.rep).collect{|p| p.id})
      rcv.joins(:roll_call => :bill)
         .where('bills.session' => 113, 'roll_call_votes.vote' => ABSTAIN_VALUES)
         .group(:person_id)
         .order('count_all DESC')
         .count
    end
  end

  #----- INSTANCE

  def atom_id
    "tag:opencongress.org,#{roll_call.date.strftime("%Y-%m-%d")}:/roll_call_vote/#{id}"
  end

  def to_s
    @@VOTE_FOR_SYMBOL[self.vote].nil? ? self.vote : @@VOTE_FOR_SYMBOL[self.vote]
  end

  def sort_date
    roll_call.date
  end

  def rss_date
    roll_call.date
  end

  # can't use a standard comparison for the next two methods because we don't want to count abstains
  def same_vote(other_vote)
    votes = [vote, other_vote.vote]
    votes.map{|v| AFFIRMATIVE_VALUES.include? v }.all? || votes.map{|v| NEGATIVE_VALUES.include? v }.all?
  end

  def different_vote(other_vote)
    votes = [vote, other_vote.vote]
    !votes.map{|v| AFFIRMATIVE_VALUES.include? v }.all? || !votes.map{|v| NEGATIVE_VALUES.include? v }.all?
  end

  def recount_party_lines
    self.roll_call.set_party_lines
  end

  def with_party?
    case self.person.party
      when 'Republican'
        ( roll_call.republican_position == true && AFFIRMATIVE_VALUES.include?(vote) ) || ( roll_call.republican_position == false && NEGATIVE_VALUES.include?(vote) )
      when 'Democrat'
        ( roll_call.democratic_position == true && AFFIRMATIVE_VALUES.include?(vote) ) || ( roll_call.democratic_position == false && NEGATIVE_VALUES.include?(vote) )
      else
        nil
      end
  end

  def is_affirmative?
    AFFIRMATIVE_VALUES.include?(vote)
  end

  def is_negative?
    NEGATIVE_VALUES.include?(vote)
  end

  def is_present?
    PRESENT_VALUES.include?(vote)
  end

  def is_non_vote?
    ABSTAIN_VALUES.include?(vote)
  end

end