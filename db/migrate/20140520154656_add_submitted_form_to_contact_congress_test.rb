class AddSubmittedFormToContactCongressTest < ActiveRecord::Migration
  def self.up
    change_table :contact_congress_tests do |t|
      t.text :submitted_form
    end
  end

  def self.down
    change_table :contact_congress_tests do |t|
      t.remove :submitted_form
    end
  end
end
