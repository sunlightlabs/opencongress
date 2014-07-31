class Search < ActiveRecord::Migration
  def self.up
    change_table :searches do |t|
      t.text :search_filters
      t.integer :page
      t.references :user, null: true
    end

  end

  def self.down
    change_table :searches do |t|
      t.remove :search_filters
      t.remove :page
      t.remove :user_id
    end
  end
end
