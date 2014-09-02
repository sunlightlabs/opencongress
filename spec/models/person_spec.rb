require 'spec_helper'

describe Person do
  describe "scopes" do
    it "should filter for democrats, republicans, and independents" do
      republicans = Person.republican.map(&:party).uniq
      republicans.first.should == "Republican"
      democrats = Person.democrat.map(&:party).uniq
      democrats.first.should == "Democrat"
      independents = Person.independent.map(&:party).uniq
      independents.should_not include("Democrat", "Republican")
    end
    it "should filter by states" do
      colorado_people = Person.in_state('CO')
      colorado_people.map(&:state).uniq.should == ["CO"]
    end
  end
end