require 'o_c_logger'
require 'united_states'

if ARGV.length > 0 and File.exist?(ARGV[0])
  rpt_file_paths = [ARGV[0]]
else
  if (ARGV.length > 0) and (/^\d+$/.match(ARGV[0]).nil? == false)
    cong_num = ARGV[0].to_i
  else
    cong_num = Settings.available_congresses.sort.last
  end
  glob_pattern = File.join(Settings.unitedstates_data_path,
                           'fdsys',
                           'CRPT',
                           '*',
                           "CRPT-#{cong_num.to_s}*",
                           'mods.xml')
  rpt_file_paths = Dir.glob(glob_pattern)
  rpt_file_paths.sort_by! { |path| [path.length, path] }
end

OCLogger.log "Found #{rpt_file_paths.count} files matching #{glob_pattern}"
rpt_file_paths.each_with_index do |rpt_path, idx|
  begin
    UnitedStates::Committees.import_committee_report_mods_file rpt_path
  rescue UnitedStates::DataValidationError => e
    OCLogger.log "Report file failed validation: #{rpt_path} #{e.to_s}"
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    OCLogger.log "Failed to import #{rpt_path} because it would duplicate a database record: #{e.to_s}"
  rescue NoMethodError
    OCLogger.log "Failed to import #{rpt_path}"
    raise
  end
end

