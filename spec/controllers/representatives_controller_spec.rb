require 'spec_helper'

describe RepresentativesController, type: :controller do
  before(:each) { get :senate }

  it "renders the senate template" do
    expect(response).to render_template('senate')
  end
end