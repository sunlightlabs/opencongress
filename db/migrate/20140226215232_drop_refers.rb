class DropRefers < ActiveRecord::Migration
  def self.up
    drop_table :refers
  end
end
