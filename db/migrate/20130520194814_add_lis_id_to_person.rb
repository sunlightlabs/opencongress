class AddLisIdToPerson < ActiveRecord::Migration
  def self.up
    add_column :people, :lis_id, :string
    # add_index :people, :lis_id
  end

  def self.down
    # remove_index :people, :lis_id
    remove_column :people, :lis_id
  end
end
