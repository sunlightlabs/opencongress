require 'spec_helper'

describe ApplicationHelper do
  describe 'position_clause' do
    it "expands the position string" do
      expect(position_clause('support')).to  eq('in support of')
      expect(position_clause('oppose')).to eq('in opposition to')
    end

    it 'defaults to tracking' do
      expect(position_clause('')).to eq('tracking')
    end
  end

end
