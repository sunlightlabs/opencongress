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
  belongs_to :person
  
  @@TYPES = {
    'sen' => 'Senator',
    'rep' => 'Representative'
  }

  scope :on_date, lambda { |date| where(['startdate <= ? and enddate >= ?', date, date]) }
  
  def display_type
    @@TYPES[role_type]
  end

  def chamber
    case role_type
    when 'rep' then 'house'
    when 'sen' then 'senate'
    else nil
    end
  end
end
