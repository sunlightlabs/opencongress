class AddIndexesToEmailCongressLetterSeeds < ActiveRecord::Migration
  def self.up
    add_index(:email_congress_letter_seeds, :confirmation_code, :unique => true)
  end

  def self.down
    remove_index(:email_congress_letter_seeds, :confirmation_code)
  end
end
