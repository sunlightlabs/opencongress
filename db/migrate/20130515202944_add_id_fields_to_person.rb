class AddIdFieldsToPerson < ActiveRecord::Migration
  def self.up
    add_column :people, :govtrack_id, :integer
    add_column :people, :fec_id, :string
    add_column :people, :thomas_id, :string
    add_column :people, :cspan_id, :integer
    add_index :people, :govtrack_id
    add_index :people, :fec_id
    add_index :people, :thomas_id
    add_index :people, :cspan_id
  end

  def self.down
    remove_index :people, :govtrack_id
    remove_index :people, :fec_id
    remove_index :people, :thomas_id
    remove_index :people, :cspan_id
    remove_column :people, :cspan_id
    remove_column :people, :thomas_id
    remove_column :people, :fec_id
    remove_column :people, :govtrack_id
  end
end
