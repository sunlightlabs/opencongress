require 'o_c_logger'

namespace :update do
  def mkdir_guard (path)
    (Dir.mkdir path) unless (Dir.exists? path)
  end

  def dl_congress_zip_archive (cong_num)
    stub = Settings.unitedstates_congress_url_stub
    sep = (s.ends_with? '/') and '' or '/'
    url = "#{stub}#{sep}#{cong_num}.zip"

    dest_dir_path = File.join(Settings.data_path, "unitedstates")
    dest_file_path = File.join(dest_dir_path, "#{cong_num}.zip")
    mkdir_guard Settings.data_path
    mkdir_guard dest_dir_path

    puts "Downloading #{url}"
    $stdout.flush
    system "curl --silent --show-error #{url} -o #{dest_file_path}"
    system "ls -lh #{dest_file_path}"
  end


  desc "Downloads bills for a specific congress"
  task :dl_named_congress => :environment do
    cong_num = ENV['cong_num']
    if cong_num.nil?
      puts 'You must specify cong_num=###'
    else
      dl_congress_zip_archive cong_num
    end
  end

  desc "Downloads bills for the latest congress"
  task :dl_latest_congress => :environment do
    latest_congress = Settings.available_congresses.sort.last
    dl_congress_zip_archive latest_congress
  end

  desc "Downloads bills for all congresses"
  task :dl_all_congresses => :environment do
    Settings.available_congresses.each do |cong_num|
      dl_congress_zip_archive cong_num
    end
  end

  desc "Clones the @unitedstates/congress-legislators repository"
  task :congress_legislators => :environment do
    clone_path = Settings.unitedstates_legislators_clone_path
    repo_url = Settings.unitedstates_legislators_repo_url

    if Dir.exist? clone_path
      system "cd #{Settings.unitedstates_legislators_clone_path} && git pull"
    else
      mkdir_guard clone_path
      system "cd #{clone_path} && git clone #{repo_url} ."
    end
  end

  desc "Fetches data from govtrack's rsync service"
  task :rsync => :environment do
    begin
      OCLogger.log "rsync with govtrack beginning...\n\n"
      system "sh #{Rails.root}/bin/daily/govtrack-rsync.sh #{Settings.data_path}"
      OCLogger.log "rsync with govtrack finished.\n\n"
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error rsyncing govtrack data!")
      else
        puts "Error rsyncing govtrack data!"
      end
      throw e
    end
  end
  
  task :mailing_list => :environment do
    load 'bin/daily/civicrm_sync.rb'
  end

  desc "Fetches legislator photos from govtrack"
  task :photos => :environment do
    begin
      system "bash #{Rails.root}/bin/daily/govtrack-photo-rsync.sh #{Settings.data_path}"
      unless (['production', 'staging'].include?(Rails.env))
        system "ln -s -i -F #{Settings.data_path}/govtrack/photos #{Rails.root}/public/images/photos"
      end
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error updating photos!")
      else
        puts "Error updating photos!"
      end
      throw e
    end
  end

  desc "Parses bioguide"
  task :bios => :environment do
    begin
      load 'bin/daily/daily_parse_bioguide.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error updating from bioguide!")
      else
        puts "Error updating from bioguide!"
      end
      throw e
    end
  end

  task :video => :environment do
    begin
      load 'bin/daily/daily_parse_video.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error getting video data!")
      else
        puts "Error getting video data!"
      end
      throw e
    end
  end

  desc "DEPRECATED: Loads legislator information from govtrack"
  task :people => :environment do
    begin
      begin
        data = IO.popen("sha1sum -c /tmp/people.sha1").read
      rescue
        data = "XXX"
      end
      
      unless data.match(/OK\n$/)
        Person.transaction {
          load 'bin/daily/daily_parse_people.rb'
        }
      else
        OCLogger.log "Legislator data file people.xml has not been updated since last parse. Skipping."
      end
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing people!")
      else
        puts "Error parsing people!"
      end
    end    
  end

  desc "Loads bills from govtrack"
  task :bills => :environment do
    begin
      load 'bin/daily/daily_parse_bills.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing bills!")
      else
        puts "Error parsing bills!"
      end
      throw e
    end
  end

  desc "Loads bill text from govtrack"
  task :bill_text => :environment do
    begin
      load 'bin/daily/daily_parse_bill_text.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing bill text!")
      else
        puts "Error parsing bill text!"
      end
      throw e
    end
  end

  task :get_watchdog_ids => :environment do
    load 'bin/get_watchdog_ids.rb'
  end

  task :sunlightlabs => :environment do
    load 'bin/get_sunlightlabs_data.rb'
  end

  task :gpo_billtext_timestamps => :environment do
    begin
      load 'bin/daily/daily_gpo_billtext_timestamps.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing GPO timestamps!")
      else
        puts "Error parsing GPO timestamps!"
      end
      throw e
    end
  end

  task :amendments => :environment do
    begin
      Amendment.transaction {
        load 'bin/daily/daily_parse_amendments.rb'
      }
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing amendments!")
      else
        puts "Error parsing amendments!"
      end
      throw e
    end
  end

  desc "Parse committee reports from Thomas"
  task :committee_reports_parse => :environment do
    begin
      CommitteeReport.transaction {
        load 'bin/thomas_parse_committee_reports.rb'
      }
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing committee reports!")
      else
        puts "Error parsing committee reports!"
      end
      throw e
    end
  end

  task :committee_reports => :environment do
    begin
      CommitteeReport.transaction {
        load 'bin/thomas_fetch_committee_reports.rb'
        load 'bin/thomas_parse_committee_reports.rb'
      }
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing committee reports!")
      else
        puts "Error parsing committee reports!"
      end
      throw e
    end
  end

  task :committee_schedule => :environment do
    begin
      CommitteeMeeting.transaction {
        load 'bin/govtrack_parse_committee_schedules.rb'
      }
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing committee schedule!")
      else
        puts "Error parsing committee schedule!"
      end
      throw e
    end    
  end

  task :today_in_congress => :environment do
    begin
      CongressSession.transaction {
        load 'bin/parse_today_in_congress.rb'
      }
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing today in Congress!")
      else
        puts "Error parsing today in Congress!"
      end
      throw e
    end
  end

  task :roll_calls => :environment do
    begin
      load 'bin/daily/daily_parse_rolls.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing roll calls!")
      else
        puts "Error parsing roll calls!"
      end
      throw e
    end
  end

  task :person_voting_similarities => :environment do
    begin
      load 'bin/daily/person_voting_similarities.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error compiling voting similarities!")
      else
        puts "Error compiling voting similarities!"
      end
      throw e
    end
  end

  task :sponsored_bill_stats => :environment do
    begin
      load 'bin/daily/sponsored_bill_stats.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error compiling sponsored bill stats!")
      else
        puts "Error compiling sponsored bill stats!"
      end
      throw e
    end
  end
  
  task :realtime => :environment do
    begin
      load 'bin/daily/drumbone_realtime_api.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing Drumbone realtime API!")
      else
        puts "Error parsing Drumbone realtime API!"
      end
      throw e
    end
  end
  
  task :project_vote_smart => :environment do
    begin
      load 'bin/daily/project_vote_smart.rb'
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error parsing PVS data!")
      else
        puts "Error parsing PVS data!"
      end
      throw e
    end
  end

  task :gossip => :environment do
    begin
      system "wget http://www.opencongress.org/news/?feed=atom -O /tmp/dev.atom"
      rss = SimpleRSS.new open("/tmp/dev.atom")
      Gossip.transaction {
        rss.entries.each do |e|
          g = Gossip.find_or_create_by_link(e[:link])
          attrs = g.attributes
          g.name = e[:author]
          g.email = "dev@opencongress.org"
          g.link = e[:link]
          g.tip = e[:content]
          g.title = e[:title]
          g.approved = true
          g.save unless g.attributes == attrs
        end
      }
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error running gossip!")
      else
        puts "Error running gossip!"
      end
      throw e
    end
  end

  task :expire_cached_bill_fragments => :environment do
    begin
      require File.dirname(__FILE__) + '/../../app/models/bill.rb'
      require File.dirname(__FILE__) + '/../../app/models/fragment_cache_sweeper.rb'

      Bill.expire_meta_govtrack_fragments

      # TO DO: only invalidate updated bills
      bills = Bill.find(:all, :conditions => ["session = ?", Settings.default_congress])
      bills.each do |b|
        b.send :expire_govtrack_fragments
      end
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error expiring cached bill fragments!")
      else
        puts "Error expiring cached bill fragments!"
      end
      throw e
    end
  end

  task :expire_cached_person_fragments => :environment do
    begin
      require File.dirname(__FILE__) + '/../../app/models/person.rb'
      require File.dirname(__FILE__) + '/../../app/models/fragment_cache_sweeper.rb'

      # TO DO: only invalidate updated people
      people = Person.all_sitting
      people.each do |p|
        p.send :expire_govtrack_fragments
      end
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.deliver_rake_error(e, "Error expiring cached person fragments!")
      else
        puts "Error expiring cached person fragments!"
      end
      throw e
    end
  end

  # CRP data tasks 
  task :crp_interest_groups => :environment do
    begin
      load 'bin/crp/parse_interest_groups.rb'
    rescue Exception => e
      #Emailer.deliver_rake_error(e, "Error compiling voting similarities!")
      throw e
    end
  end

  task :maplight_bill_positions => :environment do
    begin
      load 'bin/crp/maplight_bill_positions.rb'
    rescue Exception => e
      #Emailer.deliver_rake_error(e, "Error compiling voting similarities!")
      throw e
    end
  end
  
  task :partytime_fundraisers => :environment do
    begin
      load 'bin/crp/partytime_fundraisers.rb'
    rescue Exception => e
      #Emailer.deliver_rake_error(e, "Error compiling voting similarities!")
      throw e
    end
  end

  task :all => [:rsync, :photos, :people, :bills, :amendments, :roll_calls, :committee_reports, :committee_schedule, :person_voting_similarities, :sponsored_bill_stats, :expire_cached_bill_fragments, :expire_cached_person_fragments]
  task :parse_all => [ :people, :bills, :amendments, :roll_calls, :committee_reports, :committee_schedule]
  task :govtrack => [ :rsync, :people, :bills, :amendments, :roll_calls, :expire_cached_bill_fragments, :expire_cached_person_fragments]
  task :committee_info => [:committee_reports, :committee_schedule]
  task :people_meta_data => [:person_voting_similarities, :sponsored_bill_stats, :expire_cached_person_fragments]
end
