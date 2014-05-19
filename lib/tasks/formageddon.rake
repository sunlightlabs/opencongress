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
      else
        recipients = Person.legislator
      end
      recipients.each do |leg|
        TestFormageddonJob.perform(leg.bioguideid)
      end
    end

    desc "Tests sending to legislators which have changed since the last run"
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
  end
  task :test => "test:updated"
end
