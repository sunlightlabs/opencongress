require 'o_c_logger'
require 'json'
require 'date'
require 'united_states'

Settings.available_congresses.sort.each do |cong_num|
  OCLogger.log "Importing top CRS subjects for the #{cong_num.ordinalize} congress"

  bill_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                       cong_num.to_s,
                                       'bills',
                                       '*',
                                       '*',
                                       'data.json'))
  bill_file_paths.sort_by! { |path| [path.length, path] }

  bill_file_paths.each_with_index do |bill_file_path, idx|
    OCLogger.log "Importing top CRS subject from #{bill_file_path} (#{idx + 1} of #{bill_file_paths.count})"
    bill_hash = UnitedStates::Bills.parse_bill_file bill_file_path
    if bill_hash['subjects_top_term'].nil?
      OCLogger.log "No top subject in #{bill_file_path}"
      next
    end

    top_subject = Subject.find_by_term_icase(bill_hash['subjects_top_term'])
    if top_subject.nil?
      OCLogger.log "Top subject #{bill_hash['subjects_top_term']} not found in the database."
      next
    end

    bill_ident = UnitedStates::Bills.bill_ident(bill_hash)
    bill = Bill.where(bill_ident).first
    if bill.nil?
      OCLogger.log "Skipping #{bill_file_path} because the bill was not found in the database."
      next
    end

    bill.top_subject_id = top_subject.id
    bill.save!
  end
end
