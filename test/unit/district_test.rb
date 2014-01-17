require 'test_helper'

class DistrictTest < ActiveSupport::TestCase
  test "district tag parsing" do
    expect(District.find_by_district_tag(districts(:AK_0).tag)).to eql(districts(:AK_0))
  end
end
