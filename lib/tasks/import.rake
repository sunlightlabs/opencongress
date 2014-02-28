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
end

