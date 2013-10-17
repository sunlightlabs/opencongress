require_dependency 'united_states'
require_dependency 'viewable_object'
class RollCall < ActiveRecord::Base
  include ViewableObject
  belongs_to :bill
  belongs_to :amendment
  has_one :action
  has_many :roll_call_votes, :include => :person

  # TODO: the use of Bill.ident is wrong here. The return value has been re-ordered.
  scope :for_ident, lambda { |ident| {:conditions => ["date_part('year', roll_calls.date) = ? AND roll_calls.where = case ? when 'h' then 'house' else 'senate' end AND roll_calls.number = ?", *Bill.ident(ident)]} }
  scope :in_year, lambda { |y| { :conditions => ["date_part('year', roll_calls.date) = :y", :y => y] } }
  scope :in_congress, lambda { |cong|
    where(['date >= ? and date <= ?',
           UnitedStates::Congress.start_datetime(cong),
           UnitedStates::Congress.end_datetime(cong)])
  }
  scope :on_major_bills_for, lambda { |cong|
    includes(:bill).where(:bills => { :session => cong, :is_major => true })
  }
  scope :on_passage, lambda { where("question ILIKE 'On Passage%' OR question ILIKE 'On Motion to Concur in Senate%' OR question ILIKE 'On Concurring%'") }

  # All combinations of aye_votes, democrat_votes, democrat_aye_votes, etc.
  %W(aye nay abstain present).each do |vote|
    define_method("#{vote}_votes") { roll_call_votes.send("#{vote}s".to_sym)}
    %W(democrat republican independent).each do |party|
      define_method("#{party}_#{vote}_votes") { roll_call_votes.send("#{vote}s".to_sym).send("#{party}s".to_sym) }
    end
  end
  alias_method :non_votes, :abstain_votes
  %W(democrat republican independent).each do |party|
    define_method("#{party}_votes") { roll_call_votes.send("#{party}s".to_sym)}
  end

  @@BILL_PASSAGE_TYPES = [
    'On Passage', 'On Agreeing to the Resolution'
  ]

  @@AMDT_PASSAGE_TYPES = [
    'On Agreeing to the Amendment'
  ]

  @@PASSAGES = [
    "agreed to",
    "amendment agreed to",
    "amendment germane",
    "bill passed",
    "cloture motion agreed to",
    "concurrent resolution agreed to",
    "conference report agreed to",
    "decision of chair sustained",
    "joint resolution passed",
    "motion agreed to",
    "motion to proceed agreed to",
    "motion to reconsider agreed to",
    "motion to table agreed to",
    "nomination confirmed",
    "passed",
    "resolution agreed to",
    "veto overridden",
  ]
  @@FAILURES = [
    "amendment rejected",
    "bill defeated",
    "cloture motion rejected",
    "cloture on the motion to proceed rejected",
    "failed",
    "joint resolution defeated",
    "motion rejected",
    "motion to recommit rejected",
    "motion to table failed",
    "motion to table motion to recommit rejected",
    "resolution rejected",
  ]

  def self.passage_types
    (@@BILL_PASSAGE_TYPES + @@AMDT_PASSAGE_TYPES).flatten
  end

  #  before_save :set_party_lines
  def set_party_lines
    if republican_nay_votes.count >= republican_aye_votes.count
      self.republican_position = false
    else
      self.republican_position = true
    end

    if democrat_nay_votes.count >= democrat_aye_votes.count
      self.democratic_position = false
    else
      self.democratic_position = true
    end
    self.save
  end

  def boolean_result
    return true if @@PASSAGES.include? result.downcase or result =~ /passed|agreed to/i
    return false if @@FAILURES.include? result.downcase or result =~ /rejected|defeated|failed/i
  end

  def passed?
    boolean_result == true
  end

  def failed?
    boolean_result == false
  end

  def atom_id
    "tag:opencongress.org,#{date.strftime("%Y-%m-%d")}:/roll_call/#{id}"
  end

  def self.find_by_ident(ident_string)
    for_ident(ident_string).find(:first)
  end

  def self.ident(param_id)
    md = /(\d+)-([sh]?)(\d+)$/.match(canonical_name(param_id))
    md ? md.captures : [nil, nil, nil]
  end

  def self.find_pvs_key_votes(congress = Settings.default_congress)
    find(:all, :include => [:bill, :amendment], :order => 'roll_calls.date DESC',
                           :conditions => ['roll_calls.date > ? AND
                                          ((roll_calls.roll_type IN (?) AND bills.key_vote_category_id IS NOT NULL) OR
                                           (roll_calls.roll_type IN (?) AND amendments.key_vote_category_id IS NOT NULL))',
                  OpenCongress::Application::CONGRESS_START_DATES[Settings.default_congress], @@BILL_PASSAGE_TYPES, @@AMDT_PASSAGE_TYPES])
  end

  def vote_for_person(person)
    RollCallVote.where(["person_id=? AND roll_call_id=?", person.id, self.id]).first
  end

  def vote_url
    "/vote/#{self.date.year}/#{where[0...1]}/#{number}"
  end

  def total_votes
    (ayes + nays + abstains + presents)
  end

  def key_vote?
    return ((bill and bill.is_major) or (amendment and amendment.bill and amendment.bill.is_major))
  end

  def key_vote_category_name
    if amendment
      subject_bill = amendment.bill
    end
    if subject_bill.nil? and bill
      subject_bill = bill
    end

    if subject_bill
      root_category = Subject.root_category
      subjects = subject_bill.subjects.where(:parent_id => root_category.id)
      subjects.map(&:term).join(', ')
    else
      ""
    end
  end

  def vote_counts
    if @vote_counts.nil?
      @vote_counts = roll_call_votes.group(:vote).count
    end
    @vote_counts
  end

  def top_vote_categories (n)
    vote_counts.to_a.sort_by(&:second).reverse.slice(0, n)
  end

  def affirmative_type
    Set.new(RollCallVote::AFFIRMATIVE_VALUES).intersection(vote_counts.keys).first or 'Aye'
  end

  def negative_type
    Set.new(RollCallVote::NEGATIVE_VALUES).intersection(vote_counts.keys).first or 'Nay'
  end

  def present_type
    Set.new(RollCallVote::PRESENT_VALUES).intersection(vote_counts.keys).first or 'Present'
  end

  def non_vote_type
    Set.new(RollCallVote::ABSTAIN_VALUES).intersection(vote_counts.keys).first or 'Not Voting'
  end

  def RollCall.latest_votes_for_unique_bills(num = 3)
    RollCall.find_by_sql("SELECT * FROM roll_calls WHERE id IN
                          (SELECT max(id) AS roll_id FROM roll_calls
                           WHERE bill_id IS NOT NULL
                           GROUP BY bill_id ORDER BY roll_id DESC LIMIT #{num})
                          AND bill_id IS NOT NULL
                          ORDER BY date DESC;" )
  end


  def RollCall.latest_roll_call_date_on_govtrack
    response = nil;
    http = Net::HTTP.new("www.govtrack.us")
    http.start do |http|
      request = Net::HTTP::Get.new("/congress/votes.xpd", {"User-Agent" => Settings.scraper_useragent})
      response = http.request(request)
    end
    response.body

    doc = Hpricot(response.body)
    DateTime.parse((doc/'table[@style="font-size: 90%"]').search("nobr")[1].inner_html)
  end

  def display_title
    if bill && (not bill.title_common.empty?)
      bill.title_official
    elsif not question.nil?
      question
    else
      ""
    end
  end

  def bill_or_amendment_title
    if bill and amendment
      "#{amendment.display_number} to #{bill.title_full_common}"
    elsif bill
      "#{bill.title_full_common}"
    else
      nil
    end
  end

  def short_identifier
    if self.amendment
       self.amendment.display_number
    else
       self.bill.typenumber
    end
  end

  def chamber
    where.capitalize
  end

  def self.vote_together(person1, person2)
     together = RollCall.count_by_sql(["SELECT count(roll_calls.id)
                                        FROM roll_calls INNER JOIN (select * from roll_call_votes WHERE person_id = ? AND vote != '0') person1 on person1.roll_call_id = roll_calls.id
                                                        INNER JOIN (select * from roll_call_votes WHERE person_id = ? AND vote != '0') person2 on person2.roll_call_id = roll_calls.id
                                                        WHERE person1.vote = person2.vote", person1.id, person2.id])


     total = RollCall.count_by_sql(["SELECT count(roll_calls.id)
                                     FROM roll_calls INNER JOIN (select * from roll_call_votes WHERE person_id = ? AND vote != '0') person1 on person1.roll_call_id = roll_calls.id
                                                     INNER JOIN (select * from roll_call_votes WHERE person_id = ? AND vote != '0') person2 on person2.roll_call_id = roll_calls.id",
                                                       person1.id, person2.id])
    return [together,total]
  end

end
