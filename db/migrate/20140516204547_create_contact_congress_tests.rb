class CreateContactCongressTests < ActiveRecord::Migration
  def self.up
    create_table :contact_congress_tests do |t|
      t.string :bioguideid
      t.text :status
      t.text :after_browser_state
      t.text :values

      t.timestamps
    end
  end

  def self.down
    drop_table :contact_congress_tests
  end
end
