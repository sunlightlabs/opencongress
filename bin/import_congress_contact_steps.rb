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
Person.legislator.each do |p|
  begin
    UnitedStates::ContactCongress.import_contact_steps_for p, "#{clone_path}/members/#{p.bioguideid}.yaml"
    OCLogger.log "Updated form for #{p.bioguideid}."
    updated += 1
  rescue NoMethodError
    OCLogger.log "Unable to import #{p.firstname} #{p.lastname} (#{p.bioguideid}): <#{$!.class}: #{$!}>"
    OCLogger.log $@.join("\n")
  rescue
    # OCLogger.log "Unable to import #{p.firstname} #{p.lastname} (#{p.bioguideid}): <#{$!.class}: #{$!}>"
  end
end

OCLogger.log "Done recreating steps for #{updated} legislator(s)."