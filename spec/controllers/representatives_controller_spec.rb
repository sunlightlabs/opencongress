require 'spec_helper'

describe RepresentativesController, type: :controller do

  it "renders the senate template" do
    get(:senate)
    expect(response).to render_template('senate')
  end

  it "renders the house template" do
    get(:house)
    expect(response).to  render_template('house')
  end
end