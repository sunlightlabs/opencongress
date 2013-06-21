require 'o_c_logger'
require 'united_states'

['house', 'senate'].each do |chamber|
  path = File.join(Settings.unitedstates_data_path, "committee_meetings_#{chamber}.json")
  meetings = JSON.parse(File.read(path))

  OCLogger.log "Parsed #{meetings.length} #{chamber} meetings."
  meetings.each do |mtg_hash|
    UnitedStates::Committees.import_meeting mtg_hash
  end
end

