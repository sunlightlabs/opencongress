class CreateIdAndSessionIndexOnBills < ActiveRecord::Migration
  def self.up
    # add_index :bills, [:id, :session]
  end

  def self.down
    # remove_index :bills, [:id, :session]
  end
end
