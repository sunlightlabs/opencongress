class DropPasswordFromUsers < ActiveRecord::Migration
  def self.up
    remove_column :users, :password
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
