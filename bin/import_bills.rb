require 'o_c_logger'
require 'json'
require 'date'
require 'unitedstates'

cong_num = Settings.available_congresses.sort.last

bill_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                     cong_num.to_s,
                                     'bills',
                                     '*',
                                     '*',
                                     'data.json'))

bill_file_paths.each_with_index do |bill_file_path, idx|
  OCLogger.log "Importing bill from #{bill_file_path} (#{idx + 1} of #{bill_file_paths.count})"
  bill_hash = UnitedStates::Bills.parse_bill_file bill_file_path
  UnitedStates::Bills.import_bill bill_hash
end

bill_file_paths.each_with_index do |bill_file_path, idx|
  bill_hash = UnitedStates::Bills.parse_bill_file bill_file_path
  OCLogger.log "Linking bill #{bill_hash['bill_id']} to related bills."
  UnitedStates::Bills.link_related_bills bill_hash
end
