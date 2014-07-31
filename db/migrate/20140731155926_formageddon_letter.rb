class FormageddonLetter < ActiveRecord::Migration
  def self.up
    change_column :formageddon_letters, :subject, :text
  end

  def self.down
    change_column :formageddon_letters, :subject, :string
  end
end