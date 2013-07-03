require 'o_c_logger'
require 'json'
require 'date'
require 'united_states'

$stdin.each_line do |ln|
  ln = ln.strip
  next if ln.blank?

  begin
    amdt_type, number, congress = UnitedStates::Bills.parse_amendment_ident_string(ln)
    next if amdt_type.blank?
    next if number.blank?
    next if congress.blank?

    file_path = UnitedStates::Bills.amendment_file_path(congress, amdt_type, number)
    if not File.exists?(file_path)
      puts "No such file: #{file_path}"
      next
    end

    OCLogger.log "Importing amendment from #{file_path}"
    amdt_hash = UnitedStates::Bills.parse_amendment_file file_path
    UnitedStates::Bills.import_amendment amdt_hash

  rescue Exception => e
    puts "Unrecoverable error encountered for #{ln}: #{e}"
  end
end
