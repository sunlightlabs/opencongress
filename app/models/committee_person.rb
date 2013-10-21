class CommitteePerson < ActiveRecord::Base
  validates_uniqueness_of :person_id, :scope => [:committee_id, :session]
  validates_associated :person, :committee
  validates_presence_of :session

  set_table_name :committees_people

  belongs_to :committee
  belongs_to :person
end
