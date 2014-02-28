# lib/tasks/assets.rake
require 'fileutils'

Rake::Task['assets:precompile'].enhance do
  Rake::Task['assets:precompile_static_html'].invoke
end

namespace :assets do
  desc "Compile the static 404 and 500 html template with the correct asset path."
  task :precompile_static_html do
    invoke_or_reboot_rake_task 'assets:precompile_static_html:all'
  end

  namespace :precompile_static_html do
    def internal_precompile_static_html
      # Ensure that actionview is loaded and the appropriate
      # sprockets hooks are executed
      _ = ActionView::Base

      config = Rails.application.config
      config.assets.compile = true
      config.assets.digest = true

      env = Rails.application.assets
      target = Rails.public_path
      compiler = Sprockets::StaticCompiler.new(
        env,
        target,
        %w(404.html 500.html),
        :manifest_path => config.assets.manifest,
        :digest => false,
        :manifest => false
      )

      compiler.compile
    end

    task :all do
      ruby_rake_task('assets:precompile_static_html:primary', false)
    end

    task :primary => ['assets:environment', 'tmp:cache:clear'] do
      internal_precompile_static_html
    end
  end

  desc "Crush png images"
  task :crush_pngs do
    Dir['app/assets/**/*.png'].each do |file|
      `pngcrush -rem alla -reduce -brute "#{file}" "#{file}.crushing"`
      `mv "#{file}.crushing" "#{file}"`
    end
  end

  desc "Crush jp(e)g images"
  task :crush_jpgs do
    ( Dir['app/assets/**/*.jpg'] + Dir['public/**/*.jpeg'] ).each do |file|
      `jpegtran -copy none -optimize -perfect -outfile "#{file}.crushing" "#{file}"`
      `mv "#{file}.crushing" "#{file}"`
    end
  end

  desc "Crush images"
  task :crush_images do
    %w( assets:crush_pngs assets:crush_jpgs ).each do |task|
      Rake::Task[task].invoke
    end
  end

end
