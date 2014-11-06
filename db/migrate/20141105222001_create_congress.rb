class CreateCongress < ActiveRecord::Migration

  def self.up

    create_table :congresses, primary_key: 'number', id:false do |t|
      t.primary_key :number
      t.date :start_date
      t.date :end_date
    end

    NthCongress.create(number:109, start_date: Date.new(2005,1,3), end_date: Date.new(2007,1,3))
    NthCongress.create(number:110, start_date: Date.new(2007,1,3), end_date: Date.new(2009,1,3))
    NthCongress.create(number:111, start_date: Date.new(2009,1,3), end_date: Date.new(2011,1,3))
    NthCongress.create(number:112, start_date: Date.new(2011,1,3), end_date: Date.new(2013,1,3))
    NthCongress.create(number:113, start_date: Date.new(2013,1,3), end_date: Date.new(2015,1,3))

  end

  def self.down
    drop_table :congresses
  end

end