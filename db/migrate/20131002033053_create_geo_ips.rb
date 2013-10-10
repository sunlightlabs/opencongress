class CreateGeoIps < ActiveRecord::Migration
  def self.up
    create_table :geo_ips do |t|
      t.integer :start_ip, :index => true
      t.integer :end_ip, :index => true
      t.string :lat
      t.string :lng
      t.string :state
      t.integer :district
      t.timestamps
    end
  end

  def self.down
    drop_table :geo_ips
  end
end
