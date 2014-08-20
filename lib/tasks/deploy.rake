namespace :deploy do
  desc "Establishes the symlink from the current release public dir to the shared photos dir."
  task :relink_photos => :environment do
    system "ln -nfsv #{Settings.data_path}/govtrack/photos #{Rails.root}/app/assets/images"
  end
end

