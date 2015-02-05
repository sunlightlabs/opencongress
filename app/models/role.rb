# == Schema Information
#
# Table name: roles
#
#  id        :integer          not null, primary key
#  person_id :integer
#  role_type :string(255)
#  startdate :date
#  enddate   :date
#  party     :string(255)
#  state     :string(255)
#  district  :string(255)
#  url       :string(255)
#  address   :string(255)
#  phone     :string(255)
#  email     :string(255)
#

class Role < OpenCongressModel

  #========== CONSTANTS
  
  @@TYPES = {
    'sen' => 'Senator',
    'rep' => 'Representative'
  }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :person

  #========== SCOPES

  scope :on_date, lambda {|date| where('startdate <= ? and enddate >= ?', date, date) }

  #========== METHODS

  #----- INSTANCE

  # Returns the expanded name for the shorthand type
  #
  # @return [String] 'Senator', 'Representative'
  def display_type
    @@TYPES[role_type]
  end

  # Returns the chamber of congress associated with the role title
  #
  # @return [String, nil] 'house', 'senate', or nil
  def chamber
    case role_type
      when 'rep'
        'house'
      when 'sen'
        'senate'
      else
        nil
    end
  end

  # Determines if role is a member of a certain congress
  #
  # @param congress [Integer] congress number
  # @return [Boolean] true if member, false otherwise
  def member_of_congress?(congress=Settings.default_congress)
    target_congress = NthCongress.find(congress)
    elected_normally = self.enddate >= target_congress.end_date && self.startdate <= target_congress.start_date 
    elected_midsession = self.startdate > target_congress.start_date && self.startdate < target_congress.end_date
    elected_normally || elected_midsession
  end

end