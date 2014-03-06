namespace :billtext do
  desc "Parses text for all bills from the current congress"
  task :current => :environment do
    ParseBillTextJob.perform
  end

  desc "Parses text for all bills from a given congress"
  task :congress => :environment do
    congress = ENV['congress']
    cong_num = congress.to_i
    ParseBillTextJob.perform(:congress => cong_num)
  end

  desc "Parses text for a single bill."
  task :bill => :environment do
    bill_id = ENV['bill']
    bill_ident = Bill.ident(bill_id)
    if bill_ident.compact.empty?
      puts "You must specify a bill, E.g. bill=hr3590-111"
    else
      ParseBillTextJob.perform(:bill => bill_id)
    end
  end
end

