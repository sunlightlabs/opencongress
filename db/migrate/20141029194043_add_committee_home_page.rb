class AddCommitteeHomePage < ActiveRecord::Migration

  def self.up

    change_table :committees do |t|
      t.string :homepage_url
    end

  end

  def self.down

    change_table :committees do |t|
      t.remove :homepage_url
    end

  end

end