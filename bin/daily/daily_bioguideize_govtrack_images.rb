#!/usr/bin/env ruby

require 'rubygems'
require 'o_c_logger'

if __FILE__ == $0
  require File.dirname(__FILE__) + '/../../config/environment'
else
  OCLogger.log "Running from #{$0}"
end

found_people = 0
missing_people = 0

jpgs = Dir["#{Settings.data_path}/govtrack/photos/*.jpeg"]
jpgs.each do |jpg|
  id = jpg.match(/\/([^\/]*).jpeg/).captures.first
  begin
    person = Person.find(id.to_i)
    found_people = found_people + 1
    `cp -n /#{Settings.data_path}/govtrack/photos/#{id}.jpeg /#{Settings.data_path}/legislator_images/#{bioguideid}.jpeg`
  rescue
    OCLogger.log "person not found from GovTrack image id: #{id}"
    missing_people = missing_people + 1
  end
end

OCLogger.log "found #{found_people} People in GovTrack photo import"
OCLogger.log "missing #{missing_people} People in GovTrack photo import"
