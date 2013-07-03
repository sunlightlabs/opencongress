require 'o_c_logger'
require 'json'
require 'date'
require 'united_states'

$stdin.each_line do |ln|
  ln = ln.strip
  next if ln.blank?

  begin
    chamber_prefix, number, congress, year = UnitedStates::Votes.parse_ident_string(ln)
    next if chamber_prefix.blank?
    next if number.blank?
    next if congress.blank?
    next if year.blank?

    file_path = UnitedStates::Votes.roll_call_file_path(congress, year, chamber_prefix, number)
    if not File.exists?(file_path)
      puts "No such file: #{file_path}"
      next
    end

    OCLogger.log "Importing roll call from #{file_path}"
    vote_hash = UnitedStates::Votes.parse_roll_call_file(file_path)
    UnitedStates::Votes.import_roll_call(vote_hash)

  rescue Exception => e
    puts "Unrecoverable error encountered for #{ln}: #{e}"
  end
end
