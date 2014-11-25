class RepresentativesController < ApplicationController
  before_filter :committee_meetings
  
  def senate
    @people = Person.list_chamber('sen', Settings.default_congress, 'state, lastname');
    @parties = @people.group_by{ |person| person.party }
  end

  def house
  end

  private

  def committee_meetings
    chamber = params.action == 'senate' ? 's' : 'h'
    @committee_meetings = CommitteeMeeting.meetings_by_chamber(chamber)
  end
end