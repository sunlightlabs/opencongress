# == Schema Information
#
# Table name: congresses
#
#  number     :integer          not null, primary key
#  start_date :date
#  end_date   :date
#

class NthCongress < OpenCongressModel

  #========== ATTRIBUTES

  self.table_name = 'congresses'
  self.primary_key = 'number'

  #========== METHODS

  #----- CLASS

  def self.current
    self.last
  end

  # e.g. 2009 & 2010 -> 111th congress, 2011 & 2012 -> 112th congress
  def self.current_congress
    congress_for_year current_legislative_year
  end

  def self.congress_for_year(year)
    ((year.to_i + 1) / 2) - 894
  end

  def self.year_for_congress(cong)
    ((cong + 894) * 2) - 1
  end

  def self.start_datetime(cong)
    Time.new(year_for_congress(cong), 1, 3, 12, 0, 0)
  end

  def self.end_datetime(cong)
    Time.new(year_for_congress(cong + 1), 1, 3, 11, 59, 59)
  end

  #----- INSTANCE

  # function to calculate current legislative year from a timestamp (defaults to now)
  # legislative year - consider Jan 1, Jan 2, and first half of Jan 3 to be last year
  def current_legislative_year(now = nil)
    now ||= Time.now
    now = now.in_time_zone # enforce EST

    year = now.year
    if now.month == 1
      if [1, 2].include?(now.day)
        year - 1
      elsif (now.day == 3) && (now.hour < 12)
        year - 1
      else
        year
      end
    else
      year
    end
  end

  def previous_congress
    NthCongress.find(number-1)
  end

end