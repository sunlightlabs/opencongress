#!/usr/bin/env ruby

require 'rails'
require 'yaml'
require 'date'
require 'united_states'

require 'o_c_logger'

def usage
  program = File.basename($0)
  $stderr.puts <<-USAGE
    Usage:
    #{program} current
    #{program} all
    #{program} from-date to-date
    #{program} govtrack_id [govtrack_ids ...]

    Date ranges refer to the start or end of a term in congress.
    The default ('current') behavior is to include members with
    a term overlapping the current congress, subsuming the current
    congress, or being subsumed by the current congress.
USAGE
    exit
end

filter_proc = nil
if ARGV.length == 0 or (ARGV.length == 1 and ARGV[0] == 'current')
  current_congress_year = UnitedStates::Congress.year_for_congress(Settings.default_congress)
  cong_day1 = Date.new(current_congress_year, 1, 3)
  cong_day2 = cong_day1.tomorrow
  cong_last_day = Date.new(current_congress_year + 2, 1, 3)
  cong_2nd_last_day = cong_last_day.yesterday
  filter_proc = proc do |l|
    terms_in_this_congress = l['terms'].select do |t|
      starts_inside_current = t['+start'].between?(cong_day1, cong_2nd_last_day)
      ends_inside_current = t['+end'].between?(cong_day2, cong_last_day)
      starts_before_current = t['+start'] < cong_day1
      ends_after_current = t['+end'] > cong_last_day

      (starts_inside_current or
       ends_inside_current or
       (starts_before_current and ends_after_current))
    end
    terms_in_this_congress.length > 0
  end
    
elsif ARGV.length == 1 and ARGV[0] == 'all'
  filter_proc = proc { |l| true }

elsif ARGV.length == 2
  begin
    d1 = Date.strptime(ARGV[0], '%Y-%m-%d')
    d2 = Date.strptime(ARGV[1], '%Y-%m-%d')
    filter_proc = proc do |l|
      l['terms'].select { |t| t['+start'].between?(d1, d2) or t['+end'].between?(d1, d2) }.length > 0
    end
  rescue ArgumentError => e
    puts "The first two arguments don't look like dates. No date filter."
  end
end

if filter_proc.nil?
  not_govtrack_ids = ARGV.select { |arg| /^\d{6}$/.match(arg).nil? }
  not_govtrack_ids.each do |arg|
    puts "This doesn't look like a govtrack ID: #{arg}"
    usage
  end
  govtrack_ids = ARGV.select { |arg| not /^\d{6}$/.match(arg).nil? }
  filter_proc = proc { |l| govtrack_ids.include?(l['id']['govtrack'].to_s) }
end


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

num_sens = Person.sen.count
num_reps = Person.rep.count
if num_sens != 100
  OCLogger.log "After importing legislators there should be 100 senators but there are #{num_sens}"
end
if num_reps != 441
  OCLogger.log "After importing legislators there should be 441 reprentatives but there are #{num_reps}"
end

