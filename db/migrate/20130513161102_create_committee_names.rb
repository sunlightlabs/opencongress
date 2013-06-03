class CreateCommitteeNames < ActiveRecord::Migration
  def self.up
    create_table :committee_names do |t|
      t.integer :committee_id
      t.string :name
      t.integer :session

      t.timestamps
    end
  end

  def self.down
    drop_table :committee_names
  end
end
