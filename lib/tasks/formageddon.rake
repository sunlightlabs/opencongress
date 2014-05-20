namespace :formageddon do
  desc "Downloads replies from gmail and sends notifications to users"
  task :get_replies => :environment do
    GetFormageddonRepliesJob.perform
  end

  namespace :test do
    desc "Tests sending to all legislators, or a single one with the param BIOGUIDE"
    task :all => :environment do
      if ENV["BIOGUIDE"].present?
        recipients = [Person.find_by_bioguideid(ENV["BIOGUIDE"])]
      elsif ENV["STATUS"].present?
        case ENV["STATUS"]
        when "failed"
          ids = ContactCongressTest.recently_failed.to_a.map(&:bioguideid)
        when "unconfirmed"
          ids = ContactCongressTest.recently_unknown.to_a.map(&:bioguideid)
        else
          ids = []
        end
        recipients = Person.where(:bioguideid => ids)
      else
        recipients = Person.legislator
      end
      recipients.each do |leg|
        puts "Testing #{leg.bioguideid}..."
        TestFormageddonJob.perform(leg.bioguideid)
      end
    end

    desc "Tests sending to legislators whose files have changed since the last run"
    task :updated => :environment do
      recipients = Person.legislator
      data_path = File.join(Settings.data_path, 'contact-congress')
      datafile_path = File.join(data_path, 'members')
      recipients.each do |leg|
        last_run = ContactCongressTest.find_by_bioguideid(leg.bioguideid).created_at rescue Time.new(0)
        changed = `cd #{datafile_path} && git log -1 --since=#{last_run.iso8601} #{leg.bioguideid}.yaml`.present?
        if changed
          puts "Testing #{leg.bioguideid}..."
          TestFormageddonJob.perform(leg.bioguideid)
        else
          puts "Skipping #{leg.bioguideid}, no changes since last run."
        end
        changed = nil
        GC.start
      end
    end

    desc "Tests sending to legislators who were unconfirmed in the last run"
    task :unconfirmed => :environment do
      ENV['STATUS'] = 'unconfirmed'
      Rake::Task['formageddon:test:all'].invoke
    end

    desc "Tests sending to legislators who failed in the last run"
    task :failed => :environment do
      ENV['STATUS'] = 'failed'
      Rake::Task['formageddon:test:all'].invoke
    end

  end
  task :test => "test:updated"
end
