class AddCongressToAmendment < ActiveRecord::Migration
  def self.up
    add_column :amendments, :congress, :integer
  end

  def self.down
    remove_column :amendments, :congress
  end
end
