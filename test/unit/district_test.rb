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

require 'test_helper'

class DistrictTest < ActiveSupport::TestCase
  test "district tag parsing" do
    expect(District.find_by_district_tag(districts(:AK_0).tag)).to eql(districts(:AK_0))
  end
end
