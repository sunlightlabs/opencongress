class SetDefaultForStatusOnUsers < ActiveRecord::Migration
  def self.up
    change_column_default :users, :status, 0
  end

  def self.down
    change_column_default :users, :status, nil
  end
end
