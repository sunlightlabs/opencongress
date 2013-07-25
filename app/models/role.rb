class Role < ActiveRecord::Base
  belongs_to :person
  
  @@TYPES = {
    'sen' => 'Senator',
    'rep' => 'Representative'
  }
  
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
