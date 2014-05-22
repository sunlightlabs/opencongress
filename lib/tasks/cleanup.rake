namespace :cleanup do
  namespace :formageddon_threads do
    task :run => :environment do
      # Right now we only clean up threads from the Sunlight Era; there are a lot-lot pre Sunlight.
      # We wait 10 days before deleting your threads, in case you got lazy and didn't finish the
      # sign-in process after creating your letter.
      require 'abandoned_threads_job'
      AbandonedThreadsJob.perform(:remove => [:orphaned, :inactive],
                                  :reclaim => true,
                                  :since => '2013-10-28',
                                  :older_than => 10.days)
    end

    desc "Tests the output of cleanup:formageddon_threads"
    task :dry_run => :environment do
      require 'abandoned_threads_job'
      AbandonedThreadsJob.dry_run(:remove => [:orphaned, :inactive],
                                  :reclaim => true,
                                  :since => '2013-10-28',
                                  :older_than => 10.days)
    end

  end

  desc "Cleans up old, cobwebby Formageddon threads"
  task :formageddon_threads => "formageddon_threads:run"

  namespace :email_congress_seeds do
    desc "Deletes old email seeds."
    task :run => :environment do
      ExpiredEmailSeedsJob.perform
    end

    desc "Lists the old email seeds that would be deleted."
    task :dryrun => :environment do
      ExpiredEmailSeedsJob.perform(:dryrun => true)
    end
  end
end
