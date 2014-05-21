#!/usr/bin/env ruby
require 'united_states'
require 'o_c_logger'

def usage
  program = File.basename($0)
  $stderr.puts <<-USAGE
    Usage:
    #{program}

    This script is only able to import contact information for current
    members of congress. By default it iterates over all current members
    as defined by OpenCongress and looks for a matching file (by bioguide)
    in the unitedstates repo.
USAGE
    exit
end

updated = 0
clone_path = File.join(Settings.data_path, 'contact-congress')
datafile_path = File.join(clone_path, 'members')
Person.legislator.each do |p|
  last_build = p.formageddon_contact_steps.first.created_at || Time.new(0) rescue Time.new(0)
  changed = `cd #{datafile_path} && git log -1 --since=#{last_build.iso8601} #{p.bioguideid}.yaml`.present?
  if changed
    begin
      UnitedStates::ContactCongress.import_contact_steps_for p, "#{clone_path}/members/#{p.bioguideid}.yaml"
      OCLogger.log "Updated form for #{p.bioguideid}."
      updated += 1
    rescue NoMethodError
      OCLogger.log "Unable to import #{p.firstname} #{p.lastname} (#{p.bioguideid}): <#{$!.class}: #{$!}>"
      OCLogger.log $@.join("\n")
    rescue
      OCLogger.log "Unable to import #{p.firstname} #{p.lastname} (#{p.bioguideid}): <#{$!.class}: #{$!}>"
    end
  end
end

OCLogger.log "Done recreating steps for #{updated} legislator(s)."