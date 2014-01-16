require 'test_helper'

class PersonTest < ActiveSupport::TestCase
  test "freshman rep has one role" do
    congresses_active = people(:julia_brownley_b001285).congresses_active
    expect(congresses_active).to be_a(Array)
    expect(congresses_active.length).to eql(1)
  end

  test "sophomore senator is active in mid-term congresses" do
    congresses_active = people(:rand_paul_p000603).congresses_active
    expect(congresses_active).to be_a(Array)
    expect(congresses_active.length).to be >= 2
  end
end
