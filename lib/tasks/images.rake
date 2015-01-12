require 'o_c_logger'

namespace :images do
  desc "Fetches legislator photos from unitedstates/images and copies them to legislator_images"
  task :get_unitedstates => :environment do
    begin
      clone_path = File.join(Settings.data_path, '/unitedstates/images')
      repo_url = 'https://github.com/unitedstates/images.git'
      clone_or_update(repo_url, clone_path)
      `cp #{clone_path}/congress/original/* #{Settings.data_path}/legislator_images`
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.rake_error(e, "Error updating photos!").deliver
      else
        puts "Error updating photos!"
      end
      throw e
    end
  end

  desc "Fetches legislator photos from govtrack"
  task :get_govtrack => :environment do
    begin
      system "bash #{Rails.root}/bin/daily/govtrack-photo-rsync.sh #{Settings.data_path}"
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.rake_error(e, "Error updating photos!").deliver
      else
        puts "Error updating photos!"
      end
      throw e
    end
  end

  desc "Assigns bioguide ids to govtrack images and copies them to legislator_images"
  task :bioguideize_govtrack => :environment do
    begin
      require File.expand_path 'bin/daily/daily_bioguideize_govtrack_images', Rails.root
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.rake_error(e, "Error updating GovTrack photos!").deliver
      else
        puts "Error processing GovTrack photos!"
      end
      throw e
    end
  end

  desc "Makes sized versions of photos from UnitedStates and GovTrack"
  task :make_versions => :environment do
    begin
      system "bash #{Rails.root}/bin/daily/make-image-versions.sh #{Settings.data_path}"
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.rake_error(e, "Error error making image versions!").deliver
      else
        puts "Error making image versions!"
      end
      throw e
    end
  end

  task :link_to_public_folder => :environment do
    begin
      system "ln -nfsv #{Settings.data_path}/legislator_images #{Rails.root}/public/images/photos"
    rescue Exception => e
      if (['production', 'staging'].include?(Rails.env))
        Emailer.rake_error(e, "Error symlinking images!").deliver
      else
        puts "Error symlinking images!"
      end
      throw e
    end
  end

  task :all => [:get_unitedstates, :get_govtrack, :bioguideize_govtrack, :make_versions, :link_to_public_folder ]
end