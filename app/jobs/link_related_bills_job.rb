require 'united_states'

module LinkRelatedBillsJob
  def self.link_congress (cong_num, options = Hash.new)
    bill_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                         cong_num.to_s,
                                         'bills',
                                         '*',
                                         '*',
                                         'data.json'))
    bill_file_paths.sort_by! { |path| [path.length, path] }
    process_files(bill_file_paths)
  end

  def self.link_bill (bill_id, options = Hash.new)
    bill = Bill.find_by_ident(bill_id)
    if bill.nil?
      OCLogger.log "Unable to find bill #{bill_id}"
    else
      path = UnitedStates::Bills.file_path(bill.session, bill.bill_type, bill.number)
      process_files([path])
    end
  end

  def self.link_feed (ios, options = Hash.new)
    bill_idents = ios.readlines.map(&:strip).reject(&:empty?).compact
    resolved_idents = resolve_file_paths(bill_idents)

    resolved_idents.select{ |i| i.second.nil? }.each do |i|
      OCLogger.log "Unable to resolve file path for '#{i.first}'"
    end
    file_paths = resolved_idents.map(&:second).compact
    process_files(file_paths)
  end

  private

  def self.process_files (bill_files, options = Hash.new)
    bill_files.each do |path|
      ActiveRecord::Base.transaction do
        bill_hash = UnitedStates::Bills.parse_bill_file(path)
        UnitedStates::Bills.link_related_bills(bill_hash)

        if options[:dryrun]
          OCLogger.log "Rolling back changes since this is a dry run."
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end

