require 'spec_helper'

describe Role do
  before :each do
    (109..114).each{|n| FactoryGirl.create(:nth_congress, {number: n})}
    FactoryGirl.create(:nth_congress, {number: 64}) #for retired legislators
    @senator = FactoryGirl.create(:senator)
    @staggered_senator = FactoryGirl.create(:staggered_senator)
    @rep = FactoryGirl.create(:representative)
    @retired = FactoryGirl.create(:retired)
    @just_retired = FactoryGirl.create(:just_retired)
  end
  
  it "should know whether or not a term applies to the current congress" do
    #current members
    [@senator, @rep].each do |person|
      expect(person.roles.order("enddate desc").first.member_of_congress?(NthCongress.current.number)).to eq(true)
      expect(person.roles.order("enddate desc").first.member_of_congress?(NthCongress.current.number - 1)).to eq(false)
    end

    #retired members
    [@retired, @just_retired].each do |person|
      expect(person.roles.order("enddate desc").first.member_of_congress?(NthCongress.current.number)).to eq(false)
      expect(person.roles.order("enddate desc").first.member_of_congress?(NthCongress.congress_for_year(1916)))
    end
  end
  
  it "should default to looking at the current congress" do
    expect(@just_retired.roles.order("enddate desc").first.member_of_congress?).to eq(false)
  end

  it "should return true for people that take office _during_ a congress" do
    mid_congress_election = FactoryGirl.create(:role, {
        :role_type =>  "sen",
        :startdate => NthCongress.current.start_date + 1.year,
        :enddate => NthCongress.current.end_date + 2.years
      })
    expect(mid_congress_election.member_of_congress?).to eq(true)
  end

  it "should return true for people that resign midway through a congress" do
    mid_congress_retirement = FactoryGirl.create(:role, {
      :role_type => "rep",
      :startdate => NthCongress.current.start_date,
      :enddate => NthCongress.current.start_date + 1.year 
    })
    expect(mid_congress_retirement.member_of_congress?).to eq(true)
  end
end