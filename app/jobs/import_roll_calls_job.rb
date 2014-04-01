require 'united_states'

module ImportRollCallsJob
  def self.perform (options)
    if options[:roll_call_id]
      import_roll_call(options[:roll_call_id])
    elsif options[:congress]
      import_congress(options[:congress])
    elsif options[:feed]
      import_feed(options[:feed])
    end
  end

  def self.import_roll_call (vote_id)
    _, file_path = resolve_file_paths([vote_id]).first
    if file_path.nil?
      OCLogger.log "Unable to resolve file path for '#{vote_id}'"
    else
      import_files [file_path]
    end
  end

  def self.import_congress (cong_num)
    roll_call_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                              cong_num.to_s,
                                              'votes',
                                              '*',
                                              '*',
                                              'data.json'))
    roll_call_file_paths.sort_by! { |path| [path.length, path] }
    import_files roll_call_file_paths
  end

  def self.import_feed (ios)
    vote_idents = ios.readlines.map(&:strip).reject(&:empty?).compact
    resolved_idents = resolve_file_paths(vote_idents)

    resolved_idents.select{ |i| i.second.nil? }.each do |i|
      OCLogger.log "Unable to resolve file path for '#{i.first}'"
    end

    file_paths = resolved_idents.map(&:second).compact
    import_files file_paths
  end

  private
  def self.resolve_file_paths (vote_idents)
    vote_idents.map do |vote_ident|
      chamber_initial, number, congress, session = UnitedStates::Votes.parse_ident_string(vote_ident)
      if chamber_initial.blank? || number.blank? || congress.blank? || session.blank?
        [vote_ident, nil]
      else
        path = UnitedStates::Votes.roll_call_file_path(congress, session, chamber_initial, number)
        if File.exists?(path)
          [vote_ident, path]
        else
          [vote_ident, nil]
        end
      end
    end
  end

  def self.import_files (file_paths)
    file_paths.each_with_index do |file_path, idx|
      OCLogger.log "Importing roll call from #{file_path} (#{idx + 1} of #{file_paths.count})"
      vote_hash = UnitedStates::Votes.parse_roll_call_file(file_path)
      UnitedStates::Votes.import_roll_call vote_hash
    end
  end
end

