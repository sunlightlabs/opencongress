class ConvertIpRangesToBigint < ActiveRecord::Migration
  def self.up
    change_table :geo_ips do |t|
        t.change :start_ip, :integer, :limit => 8
        t.change :end_ip, :integer, :limit => 8
    end
  end

  def self.down
    change_table :geo_ips do |t|
        t.change :start_ip, :integer, :limit => nil
        t.change :end_ip, :integer, :limit => nil
    end
  end
end
