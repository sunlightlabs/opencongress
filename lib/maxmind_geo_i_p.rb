require 'csv'
require 'fileutils'
require 'sqlite3'
require 'o_c_logger'

module MaxmindGeoIP
  extend self

  class SystemDependencyError < StandardError
  end

  def import
    dest_dir = Settings.geoip_zip_path
    zipfile = download(dest_dir)
    ranges, locs = extract(zipfile) if zipfile.present?
    dbpath = load(ranges, locs) if ranges.present? && locs.present?
    if dbpath
      OCLogger.log('Creating GeoIp records...')
      SQLite3::Database.new(dbpath) do |db|
        GeoIp.destroy_all
        db.execute("select locs.locId, locs.country, locs.region, locs.city, locs.postalCode, locs.latitude, locs.longitude, ranges.startIpNum as start_ip, ranges.endIpNum as end_ip
                    from locs left outer join ranges on (locs.locId = ranges.locId)
                    where locs.country = 'US'
                    and locs.region != ''
                    and start_ip != ''
                    and end_ip != ''") do |row|
          begin
            state, district = Congress.districts_locate(row[5], row[6]).results.as_json.first.values
          rescue
            begin
              state, district = Congress.districts_locate(row[5], row[6]).results.as_json.first.values
            rescue
              begin
                state, district = Congress.districts_locate(row[5], row[6]).results.as_json.first.values
              rescue
                OCLogger.log("Failed at #{row} after 3 tries, moving on...")
                next
              end
            end
          end
          GeoIp.create!(:start_ip => row[7], :end_ip => row[8], :lat => row[5], :lng => row[6], :state => state, :district => district) unless district.nil?
        end
        OCLogger.log('Done!')
      end
    end
  end

  def download(dest_dir)
    OCLogger.log("Downloading IP Database to #{dest_dir}...")
    curl_bin = `which curl`.chomp
    raise SystemDependencyError, 'No `curl` found on this system!' if curl_bin.empty?
    dest_dir = File.expand_path(dest_dir, Rails.root) unless dest_dir =~ /\A\//
    filename = Settings.geoip_zip_url.split('/').last
    # FileUtils.rm_rf(dest_dir) if (dest_dir =~ /\A#{Rails.root}/ && dest_dir != Rails.root.to_s)
    # FileUtils.mkdir_p(dest_dir)
    # `curl #{Settings.geoip_zip_url} > #{dest_dir}/#{filename}`
    "#{dest_dir}/#{filename}"
  end

  def extract(path)
    OCLogger.log("Unzipping IP Database to #{path}...")
    unzip_bin = `which unzip`.chomp
    raise SystemDependencyError, 'No `unzip` found on this system!' if unzip_bin.empty?
    ranges, locs = `unzip -u -d #{File.dirname(path)} #{path}`.split.reject{ |name| name =~ /Archive|inflating|\.zip/ }.map(&:chomp)
    [ranges, locs]
  end

  def load(rangespath, locspath)
    OCLogger.log('Loading csvs...')
    ranges, locs = [File.read(rangespath).force_encoding('iso-8859-1'),
                    File.read(locspath).force_encoding('iso-8859-1')]
    path = File.dirname(rangespath)
    [ranges, locs].each {|fl| fl.sub!(/.+\n/, "") }
    dbpath = File.expand_path("geoip.db", path)
    # FileUtils.rm(dbpath) rescue nil
    # OCLogger.log('Creating database...')
    # SQLite3::Database.new(dbpath) do |db|
    #   db.execute("create table ranges (startIpNum varchar(20), endIpNum varchar(20), locId varchar(20))")
    #   CSV.parse(ranges) do |row|
    #     next if row[0] == "startIpNum"
    #     db.execute("insert into ranges (startIpNum, endIpNum, locId) values(?, ?, ?)", *row)
    #   end
    #   db.execute("create index ranges_locId on ranges (locId)")
    #   OCLogger.log('Loaded IP ranges.')
    #   db.execute("create table locs (locId varchar(20), country varchar(3), region varchar(3), city varchar(255), postalCode varchar(15), latitude varchar(20), longitude varchar(20))")
    #   CSV.parse(locs) do |row|
    #     next if row[0] == "locId"
    #     db.execute("insert into locs (locId, country, region, city, postalCode, latitude, longitude) values (?, ?, ?, ?, ?, ?, ?)", *row[0..6])
    #   end
    #   db.execute("create index locs_locId on locs (locId)")
    #   db.execute("create index locs_coutnry on locs (country)")
    #   OCLogger.log('Loaded Locations.')
    # end
    dbpath
  end
end