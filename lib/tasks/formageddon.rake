namespace :formageddon do
  desc "Downloads replies from gmail and sends notifications to users"
  task :get_replies => :environment do
    GetFormageddonRepliesJob.perform
  end
end