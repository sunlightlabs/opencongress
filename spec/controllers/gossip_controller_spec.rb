require 'spec_helper'

describe GossipController do
  describe ':update' do
    it 'should redirect when made with GET request' do
      get :update
      response.should redirect_to({:action => :index})
      
      post :update
      response.should_not redirect_to({:action => :index})
    end
  end
end
