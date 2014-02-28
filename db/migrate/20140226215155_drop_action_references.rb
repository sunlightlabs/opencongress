class DropActionReferences < ActiveRecord::Migration
  def self.up
    drop_table :action_references
  end
end
