class RepresentativesController < ApplicationController
  before_filter :committee_meetings, :people_by_chamber, :committees
  
  def senate
  end

  def house
  end

  private

  def committee_meetings
    chamber = params.action == 'senate' ? 's' : 'h'
    @committee_meetings = CommitteeMeeting.meetings_by_chamber(chamber)
  end

  def committees
    @committees = Committee.by_chamber(params.action)
  end

  def people_by_chamber
    chamber = params.action == 'senate' ? 'sen' : 'rep'
    @people = Person.list_chamber(chamber, Settings.default_congress, 'state, lastname');
    @parties = @people.group_by{ |person| person.party }
  end
end