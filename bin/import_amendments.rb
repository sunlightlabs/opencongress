require 'o_c_logger'
require 'united_states'

cong_num = Settings.available_congresses.sort.last
amdt_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                     cong_num.to_s,
                                     'amendments',
                                     '**',
                                     'data.json'))
amdt_file_paths.sort_by! { |path| [path.length, path] }

amdt_file_paths.each_with_index do |amdt_file_path, idx|
  OCLogger.log "Considering #{amdt_file_path}"
  amdt_hash = UnitedStates::Bills.parse_amendment_file amdt_file_path
  UnitedStates::Bills.import_amendment amdt_hash
end

