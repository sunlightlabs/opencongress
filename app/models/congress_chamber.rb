# == Schema Information
#
# Table name: congress_chambers
#
#  id            :integer          not null, primary key
#  chamber       :string(255)
#  size          :integer
#  congresses_id :integer
#

class CongressChamber < OpenCongressModel

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :nth_congress

  #----- HAS_MANY

  has_many :committees, :through => :congress_chamber_committees
  has_many :people, :through => :congress_chamber_peoples

  #========== METHODS

  #----- CLASS

  def self.member_title(chamber)
    case chamber
      when 'senate'
        'Sen.'
      when 'house'
        'Rep.'
      else
        raise Exception
    end
  end

  def self.default_chamber_size(chamber)
    case chamber
      when 'senate'
        Settings.senate_size
      when 'house'
        Settings.house_size
      else
        raise Exception
    end
  end

  #----- INSTANCE

  def member_title
    case self.chamber
      when 'senate'
        'Sen.'
      when 'house'
        'Rep.'
      else
        raise Exception
    end
  end

end
