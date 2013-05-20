class AddConcurrentStateAndDistrictIndexesToUser < ActiveRecord::Migration
  def ddl_transaction(&block)
    block.call  # skip transactions for this migration
  end

  def self.up
    execute "create index concurrently users_state_index on users(state)"
    execute "create index concurrently users_state_district_index on users(state, district)"
  end

  def self.down
    remove_index :users, :name => "users_state_index"
    remove_index :users, :name => "users_state_district_index"
  end
end
