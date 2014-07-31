class SearchAddCongresses < ActiveRecord::Migration
  def self.up
    change_table :searches do |t|
      t.text :search_congresses
    end

  end

  def self.down
    change_table :searches do |t|
      t.remove :search_congresses
    end
  end
end
