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
require_dependency 'notifying_object'

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
  NEGATIVE_VALUES = %W(Nay No -)
  PRESENT_VALUES = %W(Present P)
  ABSTAIN_VALUES = ['Not Voting', '0']

  #========== CALLBACKS

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

  #==========



  #========== CLASS METHODS

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

  def self.abstain_count
    cache_key = "roll_call_vote_abstain_by_person_table"
    Rails.cache.fetch(cache_key) do
      RollCallVote.includes(:roll_call => :bill)
      .where('bills.session' => 113, 'roll_call_votes.vote' => '0')
      .group(:person_id)
      .count
      .to_a
      .sort_by(&:second)
      .reverse
    end
  end

  #========== INSTANCE METHODS

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
      if ( roll_call.republican_position == true && AFFIRMATIVE_VALUES.include?(vote) ) || ( roll_call.republican_position == false && NEGATIVE_VALUES.include?(vote) )
        true
      else
        false
      end
    when 'Democrat'
      if ( roll_call.democratic_position == true && AFFIRMATIVE_VALUES.include?(vote) ) || ( roll_call.democratic_position == false && NEGATIVE_VALUES.include?(vote) )
        true
      else
        false
      end
    else
      nil
    end
  end

  def is_affirmative?
    return AFFIRMATIVE_VALUES.include?(vote)
  end

  def is_negative?
    return NEGATIVE_VALUES.include?(vote)
  end

  def is_present?
    return PRESENT_VALUES.include?(vote)
  end

  def is_non_vote?
    return ABSTAIN_VALUES.include?(vote)
  end

end