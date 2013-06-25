require 'o_c_logger'

namespace :update do
  def mkdir_guard (path)
    (Dir.mkdir path) unless (Dir.exists? path)
  end

  desc "Clones the @unitedstates/congress-legislators repository"
  task :congress_legislators => :environment do
    clone_path = File.join(Settings.data_path, 'congress-legislators')
    repo_url = 'git://github.com/unitedstates/congress-legislators.git'

    if Dir.exist? clone_path
      cmd = "cd #{clone_path} && git pull"
      OCLogger.log cmd
      system cmd
    else
      mkdir_guard clone_path
      cmd = "git clone #{repo_url} #{clone_path}"
      OCLogger.log cmd
      system cmd
    end
  end

  desc "Fetches unitedstates scraper output."
  task :unitedstates_rsync => :environment do
    begin
      src = Settings.unitedstates_rsync_source
      if src
        dst = Settings.unitedstates_data_path
        cmd = "rsync -avz #{src} #{dst}"
        OCLogger.log "Running rsync to fetch congressional data: #{cmd}"
        system cmd
        OCLogger.log "rsync command finished."
      else
        OCLogger.log "Skipping rsync due to missing unitedstates_rsync_source configuration"
      end
    rescue Exception => e
      Emailer.rake_error(e, "Error rsyncing unitedstates data!").deliver
      throw e
    end
  end

  desc "Import legislators."
  task :import_legislators do
    OCLogger.log "Importing legislators"
    `rails runner bin/import_legislators.rb current`
  end

  desc "Fetches data from govtrack's rsync service"
  task :rsync => :environment do
    begin
      OCLogger.log "rsync with govtrack beginning...\n\n"
      system "sh #{Rails.root}/bin/daily/govtrack-rsync.sh #{Settings.data_path}"
      OCLogger.log "rsync with govtrack finished.\n\n"
    rescue Exception => e
      Emailer.rake_error(e, "Error rsyncing govtrack data!").deliver
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
        system "ln -s -f -i -F #{Settings.data_path}/govtrack/photos #{Rails.root}/public/images/photos"
      end
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.rake_error(e, "Error updating photos!").deliver
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
        Emailer.rake_error(e, "Error updating from bioguide!").deliver
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
        Emailer.rake_error(e, "Error getting video data!").deliver
      else
        puts "Error getting video data!"
      end
      throw e
    end
  end

  desc "Loads bills from United States repo"
  task :bills => :environment do
    begin
      load 'bin/import_bills.rb'
    rescue Exception => e
      Emailer.rake_error(e, "Error importing bills!").deliver
      throw e
    end
  end


  desc "Loads bill text from govtrack"
  task :bill_text => :environment do
    begin
      load 'bin/daily/daily_parse_bill_text.rb'
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing bill text!").deliver
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
      Emailer.rake_error(e, "Error parsing GPO timestamps!").deliver
      throw e
    end
  end

  task :amendments => :environment do
    begin
      Amendment.transaction {
        load 'bin/daily/daily_parse_amendments.rb'
      }
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing amendments!").deliver
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
      Emailer.rake_error(e, "Error parsing committee reports!").deliver
      throw e
    end
  end

  task :committee_reports => :environment do
    begin
      CommitteeReport.transaction {
        load 'bin/import_committee_reports.rb'
      }
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing committee reports!").deliver
      throw e
    end
  end

  desc "Updates committee meetings."
  task :committee_meetings => :environment do
    begin
      CommitteeMeeting.transaction {
        load 'bin/import_committee_meetings.rb'
      }
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing committee schedule!").deliver
      throw e
    end
  end

  task :today_in_congress => :environment do
    begin
      CongressSession.transaction {
        load 'bin/parse_today_in_congress.rb'
      }
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing today in Congress!").deliver
      throw e
    end
  end

  task :roll_calls => :environment do
    begin
      load 'bin/import_roll_calls.rb'
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing roll calls!").deliver
      throw e
    end
  end

  task :person_voting_similarities => :environment do
    begin
      load 'bin/daily/person_voting_similarities.rb'
    rescue Exception => e
      Emailer.rake_error(e, "Error compiling voting similarities!").deliver
      throw e
    end
  end

  task :sponsored_bill_stats => :environment do
    begin
      load 'bin/daily/sponsored_bill_stats.rb' # new file for United States data
    rescue Exception => e
      Emailer.rake_error(e, "Error compiling sponsored bill stats!").deliver
      throw e
    end
  end

  task :realtime => :environment do
    begin
      load 'bin/daily/drumbone_realtime_api.rb'
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing Drumbone realtime API!").deliver
      throw e
    end
  end

  task :project_vote_smart => :environment do
    begin
      load 'bin/daily/project_vote_smart.rb'
    rescue Exception => e
      Emailer.rake_error(e, "Error parsing PVS data!").deliver
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
      Emailer.rake_error(e, "Error running gossip!").deliver
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
      Emailer.rake_error(e, "Error expiring cached bill fragments!").deliver
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
      Emailer.rake_error(e, "Error expiring cached person fragments!").deliver
      throw e
    end
  end

  # CRP data tasks
  task :crp_interest_groups => :environment do
    begin
      load 'bin/crp/parse_interest_groups.rb'
    rescue Exception => e
      #Emailer.rake_error(e, "Error compiling voting similarities!").deliver
      throw e
    end
  end

  task :maplight_bill_positions => :environment do
    begin
      load 'bin/crp/maplight_bill_positions.rb'
    rescue Exception => e
      #Emailer.rake_error(e, "Error compiling voting similarities!").deliver
      throw e
    end
  end

  task :partytime_fundraisers => :environment do
    begin
      load 'bin/crp/partytime_fundraisers.rb'
    rescue Exception => e
      #Emailer.rake_error(e, "Error compiling voting similarities!").deliver
      throw e
    end
  end

  task :all => [
    :unitedstates_rsync, :rsync,
    :congress_legislators, :sunlightlabs,
    :photos,
    :import_legislators, :bills,
    # Amendments are not handled yet
    #:amendments,
    :roll_calls, :committee_reports,
    :committee_meetings, :person_voting_similarities, :sponsored_bill_stats,
    :expire_cached_bill_fragments, :expire_cached_person_fragments
  ]
  task :parse_all => [ :people, :bills, :amendments, :roll_calls, :committee_reports, :committee_schedule]
  task :govtrack => [ :rsync, :bills, :bill_text ] #:amendments, :roll_calls, :expire_cached_bill_fragments, :expire_cached_person_fragments]
  task :committee_info => [:committee_reports, :committee_schedule]
  task :people_meta_data => [:person_voting_similarities, :sponsored_bill_stats, :expire_cached_person_fragments]
end

desc "Updates all congressional information in the proper order."
task :update => "update:all"
