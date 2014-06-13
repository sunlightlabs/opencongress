require File.expand_path('../boot', __FILE__)

require 'rails/all'
require File.expand_path('../../lib/extensions.rb', __FILE__)

if defined?(Bundler)
  # Remove assets group when upgrading to rails 4
  Bundler.require(:default, :assets, Rails.env)
end

# Faxable includes a railtie and must be required before the env boots
require File.expand_path('../../lib/faxable', __FILE__)

# Load ActiveRecord extensions
require File.expand_path('../../lib/active_record/humanized_attributes', __FILE__)

module OpenCongress
  class Application < Rails::Application
    # Enable the asset pipeline
    config.assets.enabled = true
    config.assets.version = '1.0'
    config.assets.paths << "#{Rails.root}/app/assets/html"
    config.assets.precompile += ['app/assets/stylesheets/*.css', 'lib/assets/stylesheets/*.css', 'vendor/assets/stylesheets/*.css', '*.js', '*.png', '*.jpg', '*.gif']

    # Detect and handle jsonp requests
    require 'rack/contrib'
    config.middleware.use 'Rack::JSONP'

    config.active_record.schema_format = :sql
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/app/models/views
                                #{config.root}/app/queries
                                #{config.root}/app/concerns
                                #{config.root}/app/jobs
                                #{config.root}/app/services
                                )

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.active_record.observers = :user_observer, :friend_observer

    # Disable delivery errors if you bad email addresses should just be ignored
    # config.action_mailer.raise_delivery_errors = false
    config.action_mailer.delivery_method = :sendmail
    # config.action_mailer.sendmail_settings = {
    #   :location       => '/usr/sbin/sendmail',
    #   :arguments      => '-i'
    # }

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Eastern Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    config.active_record.include_root_in_json = false

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :gpasswd]

    # TODO: Use wiki-internal to get wiki content on production rather
    # than going through the proxy server (twice)

    ENV['FACEBOOKER_CALLBACK_PATH'] = '/facebook'

    # we'll use this just to help debug live servers
    ENV['APP_SERVER'] = %x{hostname}.rstrip

    # following should go in application_settings.yml, but settingslogic creates
    # accessors for keys of nested hashes, and numeric keys don't work out so well,
    # whether sent as strings, symbols or integers.
    CONGRESS_START_DATES = {
      113 => '2013-01-03',
      112 => '2011-01-05',
      111 => '2009-01-01',
      110 => '2007-01-01',
      109 => '2005-01-01',
      108 => '2003-01-01',
      107 => '2001-01-01'
    }

    require 'ostruct'
  end
end
