class DropSunlightNicknameFromPerson < ActiveRecord::Migration
  def self.up
    remove_column :people, :sunlight_nickname
  end

  def self.down
    add_column :people, :sunlight_nickname, :string
  end
end
