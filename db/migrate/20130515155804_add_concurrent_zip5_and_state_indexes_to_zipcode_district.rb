class AddConcurrentZip5AndStateIndexesToZipcodeDistrict < ActiveRecord::Migration
  def self.up
    # execute "create index concurrently zipcode_district_zip5_index on zipcode_districts(zip5)"
    # execute "create index concurrently zipcode_district_state_index on zipcode_districts(state)"
  end

  def self.down
    # remove_index :zipcode_districts, "zipcode_district_zip5_index"
    # remove_index :zipcode_districts, "zipcode_district_state_index"
  end
end
