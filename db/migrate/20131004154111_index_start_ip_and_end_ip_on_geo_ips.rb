class IndexStartIpAndEndIpOnGeoIps < ActiveRecord::Migration
  def self.up
    add_index :geo_ips, [:start_ip, :end_ip]
  end

  def self.down
    remove_index :geo_ips, [:start_ip, :end_ip]
  end
end
