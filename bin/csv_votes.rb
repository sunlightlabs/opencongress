conf.echo = false

Role.class_eval do

  CONGRESSES = {
      112 => {'start_date' => Date.new(2011,01,03), 'end_date' => Date.new(2013,01,03)},
      113 => {'start_date' => Date.new(2013,01,03), 'end_date' => Date.new(2015,01,03)},
      114 => {'start_date' => Date.new(2015,01,03), 'end_date' => Date.new(2017,01,03)}
  }

  def member_of_congress?(congress=Settings.default_congress)
    target_congress = CONGRESSES[congress]
    elected_normally = self.enddate >= target_congress['end_date'] && self.startdate <= target_congress['start_date']
    elected_midsession = self.startdate > target_congress['start_date'] && self.startdate < target_congress['end_date']
    retired_midsession = self.startdate <= target_congress['start_date'] && (self.enddate < target_congress['end_date'] && self.enddate > target_congress['start_date'])
    elected_normally || elected_midsession || retired_midsession
  end

  def senator_of_congress?(congress=Settings.default_congress)
    if member_of_congress?(congress)
      self.role_type == 'sen'
    else
      false
    end
  end

  def rep_of_congress?(congress=Settings.default_congress)
    if member_of_congress?(congress)
      self.role_type == 'rep'
    else
      false
    end
  end

  def role_for_congress?(congress=Settings.default_congress)
    if member_of_congress?(congress)
      self.role_type
    else
      false
    end

  end
end

# Constants
BILL_TYPES = ["hr", "s", "sres", "hres", "sconres", "hjres", "sjres", "hconres"]
CONGRESSES_NUMS = [112,113,114]

# CSV labels
dataHash = [['bioguideid','party','title','firstname','lastname']]
CONGRESSES_NUMS.each do |session|
  BILL_TYPES.each do |bill_type|
    dataHash[0] << "sponsored_bills_#{bill_type}_#{session.to_s}"
    dataHash[0] << "cosponsored_bills_#{bill_type}_#{session.to_s}"
    dataHash[0] << "sponsored_bills_#{bill_type}_#{session.to_s}_passed_chamber"
    dataHash[0] << "cosponsored_bills_#{bill_type}_#{session.to_s}_passed_chamber"
    dataHash[0] << "sponsored_bills_#{bill_type}_#{session.to_s}_enacted"
    dataHash[0] << "cosponsored_bills_#{bill_type}_#{session.to_s}_enacted"
  end
end

Person.joins(:roles).where(["roles.person_id = people.id AND (roles.role_type='sen' OR roles.role_type='rep') AND roles.enddate > ?", Date.new(2011,1,1)]).uniq.each do |person|

  role_hash = {
      'sen' => [] ,
      'rep' => []
  }

  person.roles.each do |p_role|
    CONGRESSES_NUMS.each do |num|
      role = p_role.role_for_congress?(num)
      role_hash[role] << num if role
    end
  end

  role_hash.keys.each do |title|

    if not role_hash[title].empty?
      toAdd = []
      toAdd << person.bioguideid
      toAdd << person.party
      toAdd << ((title == 'sen') ? 'Sen.' : 'Rep.')
      toAdd << person.firstname
      toAdd << person.lastname

      CONGRESSES_NUMS.each do |session|
        BILL_TYPES.each do |bill_type|
          if not role_hash[title].include?(session)
            toAdd << 'NA' << 'NA' << 'NA' << 'NA' << 'NA' << 'NA'
          else
            sponsored_bills = Bill.where(sponsor_id:person.id, session:session, bill_type: bill_type)
            cosponsored_bills = Bill.includes(:bill_cosponsors).where('session = ? AND bills_cosponsors.person_id = ? AND bill_type = ?', session, person.id, bill_type)
            toAdd << sponsored_bills.count
            toAdd << cosponsored_bills.count
            toAdd << sponsored_bills.includes(:actions).where('actions.action_type = ? AND actions.result = ? AND actions.where = ?', 'vote', 'pass', title == 'sen' ? 's' : 'h').count
            toAdd << cosponsored_bills.includes(:actions).where('actions.action_type = ? AND actions.result = ? AND actions.where = ?', 'vote', 'pass', title == 'sen' ? 's' : 'h').count
            toAdd << sponsored_bills.includes(:actions).where('actions.action_type = ?', 'enacted').count
            toAdd << cosponsored_bills.includes(:actions).where('actions.action_type = ?', 'enacted').count
          end
        end
      end
      dataHash << toAdd
    end
  end
end

CSV.open('bill_data.csv', 'w') do |csv|
  dataHash.each do |line|
    csv << line
  end
end