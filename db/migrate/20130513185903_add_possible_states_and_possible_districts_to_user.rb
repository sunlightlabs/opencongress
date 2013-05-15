class AddPossibleStatesAndPossibleDistrictsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :possible_states, :text
    add_column :users, :possible_districts, :text
  end

  def self.down
    remove_column :users, :possible_districts
    remove_column :users, :possible_states
  end
end
