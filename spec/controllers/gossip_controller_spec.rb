require 'spec_helper'

describe GossipController, type: :controller do
  describe ':update' do
    it 'should redirect when made with GET request' do
      get :update
      expect(response).to redirect_to({:action => :index})
      
      post :update
      expect(response).not_to redirect_to({:action => :index})
    end
  end
end
