namespace :import do
  namespace :bills do
    def _options_from_env
      {:dryrun => (ENV['dryrun'] == '1'), :force => (ENV['force'] == '1')}
    end

    desc "Imports all bills from the current congress"
    task :current => :environment do
      ImportBillsJob.import_congress Settings.available_congresses.sort.last, _options_from_env()
      LinkRelatedBillsJob.link_congress Settings.available_congresses.sort.last, _options_from_env()
    end

    desc "Imports all bills from each congress"
    task :all => :environment do
      Settings.available_congresses.sort.each do |cong_num|
        ImportBillsJob.import_congress cong_num, _options_from_env()
        LinkRelatedBillsJob.link_congress cong_num, _options_from_env()
      end
    end

    desc "Imports all bills from the given congress. e.g. congress=113"
    task :congress => :environment do
      congress = ENV['congress']
      cong_num = congress.to_i
      if congress && Settings.available_congresses.include?(cong_num)
        ImportBillsJob.import_congress cong_num, _options_from_env()
        LinkRelatedBillsJob.link_congress cong_num, _options_from_env()
      else
        OCLogger.log "Invalid congress environment variable: #{congress}"
      end
    end

    desc "Imports all bills listed in the given file. e.g. feed=/tmp/bills_feed.txt"
    task :feed => :environment do
      if ENV['feed'] && File.exists?(ENV['feed'])
        File.open(ENV['feed'], 'r') do |feed_ios|
          ImportBillsJob.import_feed feed_ios, _options_from_env()
          LinkRelatedBillsJob.link_feed feed_ios, _options_from_env()
        end
      elsif ENV['feed'].blank?
        ImportBillsJob.import_feed $stdin, _options_from_env()
        LinkRelatedBillsJob.link_feed $stdin, _options_from_env()
      else
        OCLogger.log "Invalid feed argument: feed=#{ENV['feed']}"
      end
    end

    desc "Imports a single bill. e.g. bill=hr3590-111"
    task :bill => :environment do
      if ENV['bill'].present?
        ImportBillsJob.import_bill ENV['bill'], _options_from_env()
        LinkRelatedBillsJob.link_bill ENV['bill'], _options_from_env()
      else
        OCLogger.log "Missing 'bill=' argument."
      end
    end
  end

  namespace :legislators do
    desc "Imports the legislator with the given govtrack_id"
    task :individual => :environment do
      if ENV['govtrack_id']
        ImportLegislatorsJob.import_given(:govtrack => [ENV['govtrack_id']])
      end
      if ENV['thomas_id']
        ImportLegislatorsJob.import_given(:thomas => [ENV['thomas_id']])
      end
    end

    desc "Imports all legislators in the current congress"
    task :congress => :environment do
      cong_num = ENV['congress'].to_i
      cong_num and ImportLegislatorsJob.import_congress(cong_num)
    end

    desc "Imports all legislators in the current congress"
    task :current => :environment do
      # Date ranges refer to the start or end of a term in congress. The default
      # ('current') behavior is to include members with a term overlapping the
      # current congress, subsuming the current congress, or being subsumed by the
      # current congress.
      ImportLegislatorsJob.import_congress(Settings.available_congresses.sort.last)
      num_sens = Person.sen.count
      num_reps = Person.rep.count
      if num_sens != 100
        OCLogger.log "After importing legislators there should be 100 senators but there are #{num_sens}"
      end
      if num_reps != 441
        OCLogger.log "After importing legislators there should be 441 reprentatives but there are #{num_reps}"
      end
    end

    desc "Imports all legislators, from all time."
    task :all => :environment do
      ImportLegislatorsJob.import_all
    end

    desc "Imports all legislators who served between the given dates."
    task :between => :environment do
      d1 = (ENV['from'] or ENV['begin'])
      d2 = (ENV['to'] or ENV['end'])
      ImportLegislatorsJob.import_period(d1, d2)
    end
  end

  namespace :amendments do
    desc "Imports all amendments from the current congress."
    task :current => :environment do
      if !Settings.available_congresses.empty?
        ImportAmendmentsJob.import_congress(Settings.available_congresses.sort.last)
      else
        OCLogger.log "No congresses available. Check your application settings."
      end
    end

    desc "Imports all amendments from the given congress. e.g. congress=113"
    task :congress => :environment do
      congress = ENV['congress']
      cong_num = congress.to_i
      if congress && Settings.available_congresses.include?(cong_num)
        ImportAmendmentsJob.import_congress(cong_num)
      else
        OCLogger.log "Invalid congress environment variable: #{congress}"
      end
    end

    desc "Imports a single amendment. e.g. amendment=samdt3-113"
    task :amendment => :environment do
      if ENV['amendment'].present?
        ImportAmendmentsJob.import_amendment ENV['amendment']
      else
        OCLogger.log "Missing 'amendment=' argument."
      end
    end
  end

  namespace :rollcalls do
    desc "Imports all roll calls from the current congress."
    task :current => :environment do
      if !Settings.available_congresses.empty?
        ImportRollCallsJob.import_congress(Settings.available_congresses.sort.last)
      else
        OCLogger.log "No congresses available. Check your application settings."
      end
    end

    desc "Imports all roll calls from the given congress. e.g. congress=113"
    task :congress => :environment do
      congress = ENV['congress']
      cong_num = congress.to_i
      if congress && Settings.available_congresses.include?(cong_num)
        ImportRollCallsJob.import_congress(cong_num)
      else
        OCLogger.log "Invalid congress environment variable: #{congress}"
      end
    end

    desc "Imports a given roll call. e.g. rollcall=s1-113.2013"
    task :rollcall => :environment do
      if ENV['rollcall'].present?
        ImportRollCallsJob.import_roll_call ENV['rollcall']
      else
        OCLogger.log "Missing 'rollcall=' argument."
      end
    end
  end

  desc "Monitors a work queue for import jobs."
  task :worker => :environment do
    ImportQueueWorkerJob.perform()
  end
end

