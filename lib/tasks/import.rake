namespace :import do
  namespace :bills do
    desc "Imports all bills from the current congress"
    task :current => :environment do
      ImportBillsJob.import_congress Settings.available_congresses.sort.last
    end

    desc "Imports all bills from each congress"
    task :all => :environment do
      Settings.available_congresses.sort.each do |cong_num|
        ImportBillsJob.import_congress cong_num
      end
    end

    desc "Imports all bills from the given congress. e.g. congress=113"
    task :congress => :environment do
      congress = ENV['congress']
      cong_num = congress.to_i
      if congress && Settings.available_congresses.include?(cong_num)
        ImportBillsJob.import_congress cong_num
      else
        OCLogger.log "Invalid congress environment variable: #{congress}"
      end
    end

    desc "Imports all bills listed in the given file. e.g. feed=/tmp/bills_feed.txt"
    task :feed => :environment do
      if ENV['feed'] && File.exists?(ENV['feed'])
        File.open(ENV['feed'], 'r') do |feed_ios|
          ImportBillsJob.import_feed feed_ios
        end
      elsif ENV['feed'].blank?
        ImportBillsJob.import_feed $stdin
      else
        OCLogger.log "Invalid feed environment variable: #{ENV['feed']}"
      end
    end
  end
end

