class CreateCongress < ActiveRecord::Migration

  def self.up

    create_table :congresses, primary_key: 'number', id:false do |t|
      t.primary_key :number
      t.date :start_date
      t.date :end_date
    end

  end

  def self.down
    drop_table :congresses
  end

end