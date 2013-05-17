require 'o_c_logger'
require 'json'
require 'date'
require 'unitedstates'
  
ARGV.each do |path|
  if File.exist? path
    OCLogger.log "Importing bill from #{path}"
    bill_hash = UnitedStates::Bills.parse_bill_file path
    UnitedStates::Bills.import_bill bill_hash
    UnitedStates::Bills.link_related_bills bill_hash
  else
    OCLogger.log "Bill file does not exist: #{path}"
  end
end
