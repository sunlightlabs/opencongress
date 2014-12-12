require 'o_c_logger'

###################################################################
# ___   _ _____ _     ___ _  _  ___ ___ ___ _____ ___ ___  _  _   #
# |   \ /_\_   _/_\   |_ _| \| |/ __| __/ __|_   _|_ _/ _ \| \| | #
# | |) / _ \| |/ _ \   | || .` | (_ | _|\__ \ | |  | | (_) | .` | #
# |___/_/ \_\_/_/ \_\ |___|_|\_|\___|___|___/ |_| |___\___/|_|\_| #
#                                                                 #
# For more info, visit the link below.                            #
# https://gitlab.sunlightlabs.com/labs/phantom-planet/blob/master/data_ingestion/oc-data-ingestion.markdown
###################################################################

namespace :update do

  # Creates a directory at the input path if it doesn't exist.
  #
  # @param path [String] path to create directory at
  def mkdir_guard (path)
    (Dir.mkdir(path)) unless (Dir.exists?(path))
  end

  # Creates destination directory if it doesn't exist then pulls
  # data from the git repository url.
  #
  # @param url [String] URL string to git repository
  # @param dest [String] destination path on file system to pull to
  def clone_or_update (url, dest)
    mkdir_guard(dest)
    cmd =  Dir.exist?(dest) ? "cd #{dest} && git pull" : "git clone #{url} #{dest}"
    OCLogger.log cmd
    system cmd
  end

  #========== TASKS

  desc 'Clones the @unitedstates/congress-legislators repository'
  task :congress_legislators => :environment do
    clone_path = File.join(Settings.data_path, 'congress-legislators')
    repo_url = 'git://github.com/unitedstates/congress-legislators.git'
    clone_or_update repo_url, clone_path
  end

  desc 'Clones the @unitedstates/contact_congress repository'
  task :contact_congress_data => :environment do
    clone_path = File.join(Settings.data_path, 'contact-congress')
    repo_url = 'git://github.com/unitedstates/contact-congress.git'
    clone_or_update repo_url, clone_path
  end

  desc 'Sets the in-session status of both chambers of congress for today'
  task :in_session => :environment do
    require File.expand_path 'bin/parse_today_in_congress', Rails.root
  end

  # IMPORTANT: this will always fail - opencongress-us-scrapers user is handling this now.
  desc 'Fetches unitedstates scraper output.'
  task :unitedstates_rsync => :environment do
    begin
      src = Settings.unitedstates_rsync_source # will be blank in application_settings.yml
      if src
        dst = Settings.unitedstates_data_path
        cmd = "rsync -avz #{src} #{dst}"
        OCLogger.log "Running rsync to fetch congressional data: #{cmd}"
        system cmd
        OCLogger.log 'rsync command finished.'
      else
        OCLogger.log 'Skipping rsync due to missing unitedstates_rsync_source configuration'
      end
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error rsyncing unitedstates data!').deliver
      throw e
    end
  end

  desc 'Creates Formageddon mappings from the unitedstates/contact-congress repo'
  task :contact_congress => [:environment, :contact_congress_data] do
    require File.expand_path 'bin/import_congress_contact_steps.rb', Rails.root
  end

  desc "Fetches data from govtrack's rsync service"
  task :rsync => :environment do
    begin
      OCLogger.log "rsync with govtrack beginning...\n\n"
      system "sh #{Rails.root}/bin/daily/govtrack-rsync.sh #{Settings.data_path}"
      OCLogger.log "rsync with govtrack finished.\n\n"
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, "Error rsyncing govtrack data!").deliver
      throw e
    end
  end

  desc 'Fetches legislator photos from govtrack'
  task :photos => :environment do
    begin
      system "bash #{Rails.root}/bin/daily/govtrack-photo-rsync.sh #{Settings.data_path}"
      system "ln -nfsv #{Settings.data_path}/govtrack/photos #{Rails.root}/app/assets/images"
    rescue Exception => e
      if ['production', 'staging'].include?(Rails.env)
        Raven.capture_exception(e)
        #Emailer.rake_error(e, 'Error updating photos!').deliver
      else
        puts 'Error updating photos!'
      end
      throw e
    end
  end

  desc 'Parses bioguide'
  task :bios => :environment do
    begin
      require File.expand_path 'bin/daily/daily_parse_bioguide', Rails.root
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Raven.capture_exception(e)
        #Emailer.rake_error(e, 'Error updating from bioguide!').deliver
      else
        puts 'Error updating from bioguide!'
      end
      throw e
    end
  end

  desc 'Retrieves video links from various video hosting sites'
  task :video => :environment do
    begin
      require File.expand_path 'bin/daily/daily_parse_video', Rails.root
    rescue Exception => e
      if ['production', 'staging'].include?(Rails.env)
        Raven.capture_exception(e)
        #Emailer.rake_error(e, 'Error getting video data!').deliver
      else
        puts 'Error getting video data!'
      end
      throw e
    end
  end

  desc 'Loads bill text from govtrack'
  task :bill_text => :environment do
    begin
      require File.expand_path 'bin/daily/daily_parse_bill_text', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing bill text!').deliver
      throw e
    end
  end

  desc 'Gets the watchdog ids and associates them with people'
  task :get_watchdog_ids => :environment do
    require File.expand_path 'bin/get_watchdog_ids', Rails.root
  end

  desc 'Get bill text timestamps'
  task :gpo_billtext_timestamps => :environment do
    begin
      require File.expand_path 'bin/daily/daily_gpo_billtext_timestamps', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing GPO timestamps!').deliver
      throw e
    end
  end

  desc 'Import ammendments'
  task :amendments => :environment do
    begin
      Amendment.transaction { require File.expand_path 'bin/import_amendments', Rails.root }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing amendments!').deliver
      throw e
    end
  end

  desc 'Import committees'
  task :committees => :environment do
    begin
      Committee.transaction { require File.expand_path 'bin/import_committees', Rails.root }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing committees!').deliver
      throw e
    end
  end

  desc 'Import committee memberships'
  task :committee_memberships => :environment do
    begin
      Committee.transaction { require File.expand_path 'bin/import_committee_memberships', Rails.root }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing committee memberships!').deliver
      throw e
    end
  end

  desc 'Import committee reports.'
  task :committee_reports => :environment do
    begin
      CommitteeReport.transaction { require File.expand_path 'bin/import_committee_reports', Rails.root }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing committee reports!').deliver
      throw e
    end
  end

  desc 'Updates committee meetings.'
  task :committee_meetings => :environment do
    begin
      CommitteeMeeting.transaction { require File.expand_path 'bin/import_committee_meetings', Rails.root }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing committee schedule!').deliver
      throw e
    end
  end

  desc 'Import today session for Congress.'
  task :today_in_congress => :environment do
    begin
      CongressSession.transaction { require File.expand_path 'bin/parse_today_in_congress', Rails.root }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing today in Congress!').deliver
      throw e
    end
  end

  desc 'Update roll call votes.'
  task :roll_calls => :environment do
    begin
      require File.expand_path 'bin/import_roll_calls', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing roll calls!').deliver
      throw e
    end
  end

  desc 'Calculates voting similarities for members of congress.'
  task :person_voting_similarities => :environment do
    begin
      require File.expand_path 'bin/daily/person_voting_similarities', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error compiling voting similarities!').deliver
      throw e
    end
  end

  desc 'Calculates various bill statistics'
  task :sponsored_bill_stats => :environment do
    begin
      require File.expand_path 'bin/daily/sponsored_bill_stats', Rails.root # new file for United States data
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error compiling sponsored bill stats!').deliver
      throw e
    end
  end

  desc 'Associates bill nicknames with popular bills so searching for them is easier'
  task :bill_nicknames => :environment do
    begin
      clone_path = File.join(Settings.unitedstates_data_path, 'bill-nicknames')
      repo_url = 'git://github.com/unitedstates/bill-nicknames.git'
      clone_or_update repo_url, clone_path
      require File.expand_path 'bin/daily/bill_nicknames', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      throw e
    end
  end

  desc 'Calculates and stores statistics for user searches'
  task :search_stats => :environment do
    begin
      require File.expand_path 'bin/daily/search_stats', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      throw e
    end
  end


  desc 'Calculates and sentiment analysis scores for comments'
  task :comment_sentiment_analysis => :environment do
    begin
      require File.expand_path 'bin/daily/comments_sentiment_analysis', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      throw e
    end
  end

  desc 'Needs a description.'
  task :project_vote_smart => :environment do
    begin
      require File.expand_path 'bin/daily/project_vote_smart', Rails.root
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error parsing PVS data!').deliver
      throw e
    end
  end

  desc 'Needs a description.'
  task :gossip => :environment do
    begin
      system 'wget http://www.opencongress.org/news/?feed=atom -O /tmp/dev.atom'
      rss = SimpleRSS.new open('/tmp/dev.atom')
      Gossip.transaction {
        rss.entries.each do |e|
          g = Gossip.find_or_create_by_link(e[:link])
          attrs = g.attributes
          g.name = e[:author]
          g.email = 'dev@opencongress.org'
          g.link = e[:link]
          g.tip = e[:content]
          g.title = e[:title]
          g.approved = true
          g.save unless g.attributes == attrs
        end
      }
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error running gossip!').deliver
      throw e
    end
  end

  desc 'Needs a description.'
  task :expire_cached_bill_fragments => :environment do
    begin
      # require File.dirname(__FILE__) + '/../../app/models/bill.rb'
      # require File.dirname(__FILE__) + '/../../app/models/fragment_cache_sweeper.rb'

      Bill.expire_meta_govtrack_fragments

      # TODO: only invalidate updated bills
      bills = Bill.where(session: Settings.default_congress)
      bills.each do |b|
        b.send :expire_govtrack_fragments
      end
    rescue Exception => e
      #Emailer.rake_error(e, 'Error expiring cached bill fragments!').deliver
      Raven.capture_exception(e)
      throw e
    end
  end

  desc 'Needs a description.'
  task :expire_cached_person_fragments => :environment do
    begin
      # require File.dirname(__FILE__) + '/../../app/models/person.rb'
      # require File.dirname(__FILE__) + '/../../app/models/fragment_cache_sweeper.rb'

      # TODO: only invalidate updated people
      people = Person.all_sitting
      people.each do |p|
        p.send :expire_govtrack_fragments
      end
    rescue Exception => e
      Raven.capture_exception(e)
      #Emailer.rake_error(e, 'Error expiring cached person fragments!').deliver
      throw e
    end
  end

  desc 'Pulls CRP data'
  task :crp_interest_groups => :environment do
    begin
      require File.expand_path 'bin/crp/parse_interest_groups', Rails.root
    rescue Exception => e
      #Emailer.rake_error(e, 'Error compiling voting similarities!').deliver
      throw e
    end
  end

  desc 'Needs a description.'
  task :maplight_bill_positions => :environment do
    begin
      require File.expand_path 'bin/crp/maplight_bill_positions', Rails.root
    rescue Exception => e
      #Emailer.rake_error(e, 'Error compiling voting similarities!').deliver
      throw e
    end
  end

  desc 'Needs a description.'
  task :partytime_fundraisers => :environment do
    begin
      require File.expand_path 'bin/crp/partytime_fundraisers', Rails.root
    rescue Exception => e
      #Emailer.rake_error(e, 'Error compiling voting similarities!').deliver
      throw e
    end
  end

  desc 'Array of all tasks to run daily.'
  task :all => [
    :unitedstates_rsync, :rsync,
    :congress_legislators,
    :photos,
    'import:legislators:current', 'import:bills:current',
    :amendments,
    :roll_calls,
    :committees, :committee_memberships,
    :committee_reports, :committee_meetings,
    :person_voting_similarities, :sponsored_bill_stats,
    :bill_nicknames,
    #:search_stats, add back in soon
    #:comment_sentiment_analysis, add back in soon
    :in_session,
    :expire_cached_bill_fragments, :expire_cached_person_fragments, :video
  ]

  task :parse_all => [ :people, 'import:bills:current', :amendments, :roll_calls, :committee_reports, :committee_schedule]
  task :govtrack => [ :rsync, :bill_text ]
  task :committee_info => [:committee_reports, :committee_schedule]
  task :people_meta_data => [:person_voting_similarities, :sponsored_bill_stats, :expire_cached_person_fragments]

end

desc 'Updates all congressional information in the proper order.'
task :update => 'update:all'