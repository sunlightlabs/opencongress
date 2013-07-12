require 'o_c_logger'
require 'json'
require 'date'
require 'united_states'

cong_num = Settings.available_congresses.sort.last

if ARGV.length > 0 and File.exist?(ARGV[0])
  roll_call_file_paths = ARGV
else
  roll_call_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                            cong_num.to_s,
                                            'votes',
                                            '*',
                                            '*',
                                            'data.json'))
end

roll_call_file_paths.each_with_index do |file_path, idx|
  OCLogger.log "Importing roll call from #{file_path} (#{idx + 1} of #{roll_call_file_paths.count})"
  vote_hash = UnitedStates::Votes.parse_roll_call_file(file_path)
  UnitedStates::Votes.import_roll_call vote_hash
end

