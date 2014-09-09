require 'spec_helper'


describe IndexController, type: :controller do
  render_views
  describe 'index' do
    it 'should load' do
      get :index
      expect(response).to be_success
    end
  end
end
