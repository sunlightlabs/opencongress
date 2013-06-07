require 'o_c_logger'
require 'unitedstates'

house_path = File.join(Settings.unitedstates_data_path, 'committee_meetings_house.json')
house_meetings = JSON.parse(File.read(house_path))

OCLogger.log "Parsed #{house_meetings.length} meetings."
house_meetings.each do |mtg_hash|
  UnitedStates::Committees.import_meeting mtg_hash
end

