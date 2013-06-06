class CommitteeMeeting < ActiveRecord::Base
  # TODO Since committee meeting times are all the same (a bug)
  # this was preventing any committee from having more than one meeting.
  # Once committee meeting times have been fixed, this should be re-enabled.
  # validates_uniqueness_of :meeting_at, :scope => :committee_id

  belongs_to :committee

  has_many :committee_meetings_bills 
  has_many :bills, :through => :committee_meetings_bills
end
