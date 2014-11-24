require 'spec_helper'

describe CongressSession do
  describe "senate_session" do
    session = FactoryGirl.create(:congress_session)

    it "return the current senate sessionate" do      
      expect(CongressSession.senate_session).to eq session
    end
  end
end
