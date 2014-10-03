class CreatePersonIdentifiers < ActiveRecord::Migration
  def self.up
    puts "creating table person_identifiers"
    create_table :person_identifiers do |t|
      t.integer :person_id
      t.string :bioguideid
      t.text :namespace
      t.text :value
      t.timestamps
    end
    add_index :person_identifiers, :bioguideid  
  end
  def self.down
    drop_table :person_identifiers
  end
end
