class AlterLetters < ActiveRecord::Migration
  def self.up
    change_column :formageddon_letters, :status, :text
  end

  def self.down
    change_column :formageddon_letters, :status, :string
  end
end
