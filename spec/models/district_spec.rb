# == Schema Information
#
# Table name: districts
#
#  id              :integer          not null, primary key
#  district_number :integer
#  state_id        :integer
#  created_at      :datetime
#  updated_at      :datetime
#  center_lat      :decimal(15, 10)
#  center_lng      :decimal(15, 10)
#

require 'spec_helper'

describe District do
  describe "from_address" do
    it "returns 42223 state overlap" do
      dsts = District.from_address('42223')
      expect(dsts.length).to eq(2)
      states = dsts.map{ |d| d.state.abbreviation }.uniq.sort
      expect(states.length).to eq(2)
      expect(states).to eq(['KY', 'TN'])
    end

    it "identifies KY-1 in 42223" do
      ky1 = District.includes(:state).where(:district_number => 1,
                                            :states => { :abbreviation => 'KY' }).first
      dst = District.from_address('Fort Campbell, KY 42223').first
      expect(dst).to eq(ky1)
    end

    it "identifies TN-7 in 42223" do
      tn7 = District.includes(:state).where(:district_number => 7,
                                            :states => { :abbreviation => 'TN' }).first
      dst = District.from_address('Clarksville, TN 42223').first
      expect(dst).to eq(tn7)
    end
  end
end


