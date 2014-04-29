require 'united_states'

module ImportLegislatorsJob
  def self.perform (options={})
    filter_proc = options[:filter]
    filter_proc or (raise 'You must provide a :filter option')


    legislators = ['current', 'historical'].flat_map do |mode|
      legislators_file_path = File.join(Settings.data_path,
                                        "congress-legislators",
                                        "legislators-#{mode}.yaml")
      legislators = YAML.load_file(legislators_file_path)
      legislators.map do |leg_hash| 
        UnitedStates::Legislators.decode_legislator_hash(leg_hash)
      end
    end

    legislators.select!(&filter_proc)
    legislators.each_with_index do |leg_hash, idx|
      OCLogger.log "Updating Legislator: #{leg_hash['id']['govtrack']} (#{idx + 1} of #{legislators.count})"
      UnitedStates::Legislators.import_legislator leg_hash
    end
  end

  def self.import_congress (cong_num)
    congress_year = UnitedStates::Congress.year_for_congress(cong_num)
    cong_day1 = Date.new(congress_year, 1, 3)
    cong_day2 = cong_day1.tomorrow
    cong_last_day = Date.new(congress_year + 2, 1, 3)
    cong_2nd_last_day = cong_last_day.yesterday
    perform(:filter => proc { |l|
      terms_in_this_congress = l['terms'].select do |t|
        starts_inside_current = t['+start'].between?(cong_day1, cong_2nd_last_day)
        ends_inside_current = t['+end'].between?(cong_day2, cong_last_day)
        starts_before_current = t['+start'] < cong_day1
        ends_after_current = t['+end'] > cong_last_day

        (starts_inside_current ||
         ends_inside_current ||
         (starts_before_current && ends_after_current))
      end
      terms_in_this_congress.length > 0
    })
  end

  def self.import_given (options)
    govtrack_ids = options.fetch(:govtrack, [])
    thomas_ids = options.fetch(:thomas, [])
    perform(:filter => proc { |l|
      (govtrack_ids.include?(l['id']['govtrack'].to_s) || thomas_ids.include?(l['id']['thomas'].to_s))
    })
  end

  def self.import_all
    perform(:filter => proc { |l| true })
  end

  def self.import_period (d1, d2)
    begin
      d1 = Date.strptime(d1, '%Y-%m-%d') if d1.is_a?(String)
      d2 = Date.strptime(d2, '%Y-%m-%d') if d2.is_a?(String)
      perform(:filter => proc { |l|
        l['terms'].select { |t| t['+start'].between?(d1, d2) or t['+end'].between?(d1, d2) }.length > 0
      })
    rescue ArgumentError => e
      puts "Error parsing date: #{e}"
    end
  end
end

