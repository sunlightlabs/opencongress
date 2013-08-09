class AddIndexesToRolesOnDatesAndType < ActiveRecord::Migration
  def self.up
    add_index :roles, :startdate
    add_index :roles, :enddate
    add_index :roles, :role_type
  end

  def self.down
    remove_index :roles, :startdate
    remove_index :roles, :enddate
    remove_index :roles, :role_type
  end
end
