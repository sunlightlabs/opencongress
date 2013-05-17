class ChangeBillTypeWidth < ActiveRecord::Migration
  def self.up
    change_column :bills, :bill_type, :string, :limit => 7
  end

  def self.down
    change_column :bills, :bill_type, :string, :limit => 2
  end
end
