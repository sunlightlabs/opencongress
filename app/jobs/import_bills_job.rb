require 'united_states'

module ImportBillsJob

  def self.set_defaults (options)
    options[:force] ||= false
    options[:dryrun] ||= false
  end

  def self.import_congress (cong_num, options = Hash.new)
    set_defaults options
    bill_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                         cong_num.to_s,
                                         'bills',
                                         '*',
                                         '*',
                                         'data.json'))
    bill_file_paths.sort_by! { |path| [path.length, path] }
    import_files bill_file_paths, options
  end

  def self.import_bill (bill_id, options = Hash.new)
    set_defaults options
    bill = Bill.find_by_ident(bill_id)
    if bill.nil?
      OCLogger.log "Unable to find bill #{bill_id}"
    else
      bill_file_paths = resolve_file_paths([bill_id]).map(&:second).compact
      import_files bill_file_paths, options
    end
  end

  def self.import_feed (ios, options = Hash.new)
    set_defaults options
    bill_idents = ios.readlines.map(&:strip).reject(&:empty?).compact
    resolved_idents = resolve_file_paths(bill_idents)

    resolved_idents.select{ |i| i.second.nil? }.each do |i|
      OCLogger.log "Unable to resolve file path for '#{i.first}'"
    end

    file_paths = resolved_idents.map(&:second).compact
    import_files file_paths, options
  end

  private

  def self.import_files (file_paths, options = {})

    file_paths.each_with_index do |bill_file_path, idx|
      # We only isolate each bill import using the dry-run transaction. Bill imports should be
      # depend on other bills and transacting the import of a substantial number of bills is
      # unacceptably slow.
      ActiveRecord::Base.transaction do
        OCLogger.log "Importing bill from #{bill_file_path} (#{idx + 1} of #{file_paths.count})"
        bill_hash = UnitedStates::Bills.parse_bill_file bill_file_path
        UnitedStates::Bills.import_bill bill_hash, options

        if options[:dryrun]
          OCLogger.log "Rolling back changes since this is a dry run."
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  def self.resolve_file_paths (bill_idents)
    bill_idents.map do |bill_ident|
      bill_type, number, congress = Bill.ident(bill_ident)
      if bill_type.blank? || number.blank? || congress.blank?
        [bill_ident, nil]
      else
        file_path = UnitedStates::Bills.file_path(congress, bill_type, number)
        if File.exists?(file_path)
          [bill_ident, file_path]
        else
          [bill_ident, nil]
        end
      end
    end
  end
end

