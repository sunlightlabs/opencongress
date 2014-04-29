class AddOrdinalPositionToAction < ActiveRecord::Migration
  def self.up
    add_column :actions, :ordinal_position, :integer
  end

  def self.down
    remove_column :actions, :ordinal_position
  end
end
