class AssignStatesToDistrictGroups < ActiveRecord::Migration
  def self.up
    Group.where("district_id is not null").each do |g|
        g.state = g.district.state
        g.save
    end
  end

  def self.down
  end
end
