class AddConcurrentStateAndDistrictIndexesToUser < ActiveRecord::Migration
  def self.up
    # execute "create index concurrently users_state_index on users(state)"
    # execute "create index concurrently users_state_district_index on users(state, district)"
  end

  def self.down
    # remove_index :users, :name => "users_state_index"
    # remove_index :users, :name => "users_state_district_index"
  end
end
