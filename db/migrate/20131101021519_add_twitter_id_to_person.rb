class AddTwitterIdToPerson < ActiveRecord::Migration
  def self.up
    add_column :people, :twitter_id, :string
  end

  def self.down
    remove_column :people, :twitter_id, :string
  end
end
