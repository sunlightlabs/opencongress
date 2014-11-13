class AddSourceFieldToContactCongressLetters < ActiveRecord::Migration

  def self.up

    change_table :contact_congress_letters do |t|
      t.integer :source
    end

  end

  def self.down

    change_table :contact_congress_letters do |t|
      t.remove :source
    end

  end

end