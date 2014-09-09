require 'spec_helper'

describe Person do
  describe "scopes" do
    it "should filter for democrats, republicans, and independents" do
      republicans = Person.republican.map(&:party).uniq
      expect(republicans.first).to  eq("Republican")
      democrats = Person.democrat.map(&:party).uniq
      expect(democrats.first).to eq("Democrat")
      independents = Person.independent.map(&:party).uniq
      expect(independents).not_to include("Democrat", "Republican")
    end
    it "should filter by states" do
      colorado_people = Person.in_state('CO')
      expect(colorado_people.map(&:state).uniq).to eq(["CO"])
    end
  end
end