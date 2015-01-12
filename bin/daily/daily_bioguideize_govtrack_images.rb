#!/usr/bin/env ruby

require 'rubygems'
require 'o_c_logger'

if __FILE__ == $0
  require File.dirname(__FILE__) + '/../../config/environment'
else
  OCLogger.log "Running from #{$0}"
end

found_people = 0
found_people_without_bioguides = 0
missing_people = 0

jpgs = Dir["#{Settings.data_path}/govtrack/photos/*.jpeg"]
jpgs.each do |jpg|
  id = jpg.match(/\/([^\/]*).jpeg/).captures.first
  begin
    person = Person.find(id)
    found_people = found_people + 1
    `cp -n /#{Settings.data_path}/govtrack/photos/#{id}.jpeg /#{Settings.data_path}/legislator_images/#{bioguideid}.jpeg`
  rescue
    OCLogger.log "person not found: #{id}"
    missing_people = missing_people + 1
  end
end
