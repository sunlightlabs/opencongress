require 'o_c_logger'
require 'json'
require 'date'
require 'united_states'

imported_bills = []

$stdin.each_line do |ln|
  ln = ln.strip
  next if ln.blank?

  begin
    bill_type, number, congress = Bill.ident(ln)
    next if bill_type.blank?
    next if number.blank?
    next if congress.blank?

    file_path = UnitedStates::Bills.file_path(congress, bill_type, number)
    if not File.exists?(file_path)
      puts "No such file: #{file_path}"
      next
    end
    
    OCLogger.log "Importing bill from #{file_path}"
    bill_hash = UnitedStates::Bills.parse_bill_file file_path
    UnitedStates::Bills.import_bill bill_hash, :force => true
    imported_bills.push(bill_hash)

  rescue Exception => e
    puts "Unrecoverable error encountered for #{ln}: #{e}"
  end
end

imported_bills.each do |bill_hash|
  OCLogger.log "Linking bill #{bill_hash['bill_id']} to related bills."
  UnitedStates::Bills.link_related_bills bill_hash
end
