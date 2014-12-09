require 'spec_helper'

describe CongressSession do
  before(:each) { @session = FactoryGirl.create(:congress_session) }
  
  describe "senate_session" do
    it "return the current senate sessionate" do      
      expect(CongressSession.senate_session).to eq @session
    end
  end
  
end
