class BillVote < ActiveRecord::Base
  include Tire::Model::Search
  include Tire::Model::Callbacks

  # 1 = opposed, 0 = supported
  belongs_to :user
  belongs_to :bill
  after_save :save_associated_user
  after_save :update_last_user_vote_on_bill

  scope :supporting, where(:support => 0)
  scope :opposing, where(:support => 1)

  POSITION_CHOICES = { :support => 0, :oppose => 1 }

  def self.position_value (position)
      case position
      when :support, :supporting then 0
      when :oppose, :opposing then 1
      else raise ArgumentError.new("Expecting :support, :supporting, :oppose, or :opposing")
      end
  end

  def self.count_in_period (from, to)
    @_bill_vote_count_in_period ||= {}
    @_bill_vote_count_in_period["#{from}..#{to}"] ||= self.where(:updated_at => from..to).count
  end

  def self.freq_for_period (from, to, options = {})
    bill_votes = BillVote.where(:updated_at => from..to)
    if options[:position]
      support_value = self.position_value(options[:position])
      bill_votes = bill_votes.where(:support => support_value)
    end
    bill_votes.group(:bill_id).count(:order => "COUNT(bill_id) DESC, bill_id ASC")
  end

  def self.bill_ranking_for_period (from, to, options = {})
    rank_by = options[:rank_by] || :votes

    # Frequency of user votes for bill_ids
    bill_votes = {}
    bill_votes[:support] = BillVote.freq_for_period(from, to, :position => :support)
    bill_votes[:oppose] = BillVote.freq_for_period(from, to, :position => :oppose)
    bill_votes[:votes] = BillVote.freq_for_period(from, to)

    counts_by_bill_id = bill_votes[rank_by]

    # Frequency of counts observed in the frequency table above (needed
    # for ties)
    vote_count_frequency = counts_by_bill_id.values.reduce({}) do |h, rank|
      h.update({rank => h.fetch(rank, 0) + 1})
    end

    # The rank for each count
    ranking_by_count = Hash[vote_count_frequency.keys.sort.reverse.to_enum.with_index.to_a]

    # Unwrap a list of [[[bill_id, count], ix], ...]
    # and re-wrap as a list of [[bill_id, [count, ix]], ...]
    ranking = counts_by_bill_id.to_enum.map do |bill_id, count|
      { :bill_id => bill_id,
        :counts => {
          :votes => bill_votes[:votes][bill_id],
          :support => bill_votes[:support][bill_id],
          :oppose => bill_votes[:oppose][bill_id]
        },
        :rank => { :ordinal => ranking_by_count[count],
                   :peers => vote_count_frequency[count] }
      }
    end
    ranking.sort_by{ |r| r[:counts][rank_by] }.reverse
  end

  def self.bill_ranking_diff (previous, current)
    previous_lookup = Hash[previous.map{ |record| [record[:bill_id], record] }]
    current_lookup = Hash[current.map{ |record| [record[:bill_id], record] }]

    shared_bill_ids = Set.new(previous_lookup.keys) & Set.new(current_lookup.keys)
    Hash[
      shared_bill_ids.map do |bill_id|
        [bill_id, current_lookup[bill_id][:rank][:ordinal] - previous_lookup[bill_id][:rank][:ordinal]]
      end
    ]
  end

  def self.is_valid_user_position (position)
    position = position.to_sym if position.class == String
    if position.class == Symbol
      POSITION_CHOICES.keys.include?(position)
    else
      false
    end
  end

  def self.current_user_position (bill, user)
    # Demote bill and user to their id
    bill_id = (bill.class == Bill) ? bill.id : bill
    user_id = (user.class == User) ? user.id : user
    bv = BillVote.where(:bill_id => bill_id, :user_id => user_id).first
    if bv.nil?
      return nil
    else
      return POSITION_CHOICES.invert[bv.support]
    end
  end

  def self.establish_user_position (bill, user, position)
    # Demote bill and user to their id
    bill_id = (bill.class == Bill) ? bill.id : bill
    user_id = (user.class == User) ? user.id : user

    if POSITION_CHOICES.include?(position)
      bv = BillVote.where(:bill_id => bill_id, :user_id => user_id).first
      if bv.nil?
        bv = BillVote.new(:bill_id => bill_id, :user_id => user_id, :support => nil)
      end

      if bv.support != POSITION_CHOICES[position]
        bv.support = POSITION_CHOICES[position]
        bv.save!
      end
      return bv
    else
      return nil
    end
  end

  private
  def update_last_user_vote_on_bill
    bill.last_user_vote = updated_at
    bill.save!
  end

  mapping do
    indexes :bill_id,        :index => :not_analyzed
    indexes :user_id,        :index => :not_analyzed
    indexes :support,        :type => :integer, :as => proc { support.to_i }
    indexes :created_at,     :type => :date
    indexes :updated_at,     :type => :date
    indexes :bill_congress,  :type => :integer, :as => proc { bill && bill.session }
  end
end
