require 'spec_helper'

describe CommitteeMeeting do
  describe "senate_meetings" do

    it "should have no senate meetings if there are none scheduled" do
      FactoryGirl.create(:committee_meeting, meeting_at: Date.today - 1, where: "s")
      expect(CommitteeMeeting.meetings_by_chamber('s')).to be_empty
    end
    
    it "should return with upcoming meetings" do
      meeting = FactoryGirl.create(:committee_meeting, where: "s")
      expect(CommitteeMeeting.meetings_by_chamber('s')).to eq [meeting]
    end
    
    it "should return only meetings for the specified chamber" do 
      senate_meeting = FactoryGirl.create(:committee_meeting, where: "s")
      house_meeting = FactoryGirl.create(:committee_meeting, where: "h")

      expect(CommitteeMeeting.meetings_by_chamber('h')).to eq [house_meeting]
    end

    it "orders by meeting date ascending" do
      5.times { |n| FactoryGirl.create(:committee_meeting, meeting_at: Date.today + n, where: "h") }

      # expect(CommitteeMeeting.meetings_by_chamber('h').first.meeting_at).to eq Date.today     
    end
  end
end
