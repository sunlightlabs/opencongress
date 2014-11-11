class CreateCongressChamberModel < ActiveRecord::Migration
  def self.up

    create_table :congress_chambers do |t|
      t.string :chamber
      t.integer :size
      t.belongs_to :congresses
    end

    create_table :congress_chamber_people do |t|
      t.belongs_to :congress_chambers
      t.belongs_to :people
      t.timestamps
    end

    create_table :congress_chamber_committees do |t|
      t.belongs_to :congress_chambers
      t.belongs_to :committees
      t.timestamps
    end

    NthCongress.all.each do |c|
      CongressChamber.create(chamber: 'house', size: Settings.house_size, congresses_id: c.number)
      CongressChamber.create(chamber: 'senate', size: Settings.senate_size, congresses_id: c.number)
    end

  end

  def self.down
    drop_table :congress_chambers
    drop_table :congress_chamber_people
    drop_table :congress_chamber_committees
  end

end