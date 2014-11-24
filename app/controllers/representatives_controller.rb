class RepresentativesController < ApplicationController
  
  def senate
    @people = Person.list_chamber('sen', Settings.default_congress, 'state, lastname');
    @parties = @people.group_by{ |person| person.party }
  end

  def house
  end
end