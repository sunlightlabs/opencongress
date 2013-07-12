class AddAkismetFieldsToComment < ActiveRecord::Migration
  def self.up
    add_column :comments, :permalink, :string
    add_column :comments, :user_agent, :text
    add_column :comments, :referrer, :string
  end

  def self.down
    remove_column :comments, :permalink
    remove_column :comments, :user_agent
    remove_column :comments, :referrer
  end
end
