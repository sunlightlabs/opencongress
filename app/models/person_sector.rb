class PersonSector < ActiveRecord::Base
  self.table_name = 'people_sectors'

  belongs_to :person
  belongs_to :sector
end
