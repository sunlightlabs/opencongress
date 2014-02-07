require 'united_states'

module ImportBillsJob
  def self.import_congress (cong_num)
    bill_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                         cong_num.to_s,
                                         'bills',
                                         '*',
                                         '*',
                                         'data.json'))
    bill_file_paths.sort_by! { |path| [path.length, path] }
    self.import_files bill_file_paths
  end

  def self.import_feed (ios)
    bill_idents = ios.readlines.map(&:strip).reject(&:empty?).compact
    resolved_idents = self.resolve_file_paths(bill_idents)

    resolved_idents.select{ |i| i.second.nil? }.each do |i|
      OCLogger.log "Unable to resolve file path for '#{i.first}'"
    end

    file_paths = resolved_idents.map(&:second).compact
    self.import_files file_paths, :force => true
  end

  private

  def self.import_files (file_paths, options = {})
    options[:force] ||= false

    file_paths.each_with_index do |bill_file_path, idx|
      OCLogger.log "Importing bill from #{bill_file_path} (#{idx + 1} of #{file_paths.count})"
      bill_hash = UnitedStates::Bills.parse_bill_file bill_file_path
      UnitedStates::Bills.import_bill bill_hash, options
    end

    file_paths.each_with_index do |bill_file_path, idx|
      bill_hash = UnitedStates::Bills.parse_bill_file bill_file_path
      OCLogger.log "Linking bill #{bill_hash['bill_id']} to related bills."
      UnitedStates::Bills.link_related_bills bill_hash
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

