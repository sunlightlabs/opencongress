source 'http://rubygems.org'

gem 'rails', '~> 3.2.0'
gem 'rake'
# gem 'protected_attributes' # Rails 4 removed attr_accessible

# database gems -- need both pg and mysql for app and wiki
gem 'pg'
gem 'mysql'
gem "settingslogic"
gem 'titlecase'
gem "haml-rails"
gem 'rabl', '>=0.5.4'
gem 'oj'
gem 'delayed_job'
gem 'rmagick', '~> 2.13.1', :require => "RMagick"
gem "galetahub-simple_captcha", '0.1.3', :require => "simple_captcha"
gem 'rakismet'
gem 'carrierwave'
gem 'fog'
gem "awesome_nested_set", ">= 2.0"
gem 'curb'

gem 'postmark-mitt'
gem "congress"
gem 'paperclip'
gem 'unicode_utils'

# Geocoding users on create
gem 'geocoder', :git => 'git://github.com/sunlightlabs/geocoder.git'

# Split names for first/last support
gem 'full-name-splitter'
# And determine their gender
gem 'sexmachine'

gem 'awesome_print'

gem 'ruby-openid'
gem 'rack-openid'
gem 'rack-contrib'
gem 'memcache-client'
gem 'beanstalk-client'
gem 'oauth'
gem 'twitter_oauth'
gem 'facebooker2'
gem "validates_captcha"
gem "open_id_authentication"
gem 'will_paginate'
gem 'acts-as-taggable-on'
gem 'simple_form'

# markup tools and parsers
gem 'simple-rss'
gem 'mediacloth'
gem 'hpricot'
gem 'RedCloth'
gem 'bluecloth'
gem 'htmlentities'
gem 'json'
gem 'nokogiri'
gem 'possessive'

# Mail
gem 'mechanize'

gem 'formageddon', '~> 0.0.2', :git => 'git://github.com/sunlightlabs/formageddon.git'

gem 'postmark-rails'
# Faxing
gem 'phaxio'
# apt-get or brew `install xvfb wkhtmltopdf` first!
# You'll have to build QT yourself on Ubuntu: https://code.google.com/p/wkhtmltopdf/wiki/compilation
gem 'pdfkit'

## Production code coverage (dead code finder)
# gem 'coverband', :git => 'https://github.com/danmayer/coverband.git'

## Assets group was removed in Rails 4
group :assets do
  gem "sass-rails", ">= 3.2"
  gem "bootstrap-sass", "~>2.1.1"
  gem "uglifier"
  gem "closure-compiler"
  gem "jquery-rails"
  gem "jquery-migrate-rails"
  gem "prototype-rails"
  gem "ejs"
end

group :deployment do
  gem 'capistrano'
  gem 'capistrano-ext'
end

group :production do
  # new relic RPM
  gem 'newrelic_rpm'
end

group :production, :staging do
  gem 'unicorn'
  gem 'sentry-raven' #, :git => "git://github.com/getsentry/raven-ruby.git"
end

group :test, :development do
  #gem 'debugger'
  gem 'annotate',             '>=2.6.0'
  gem 'pry'
  gem 'pry-nav'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
  gem 'pry-debugger'
  gem 'rails_best_practices'
  gem 'simplecov',            :require => false
  gem 'guard'
  gem 'guard-livereload'
  gem 'rack-mini-profiler'
  gem 'redis'
  gem 'rspec-rails'
  gem 'random_data'
end

group :test do
  gem 'silent-postgres'  # Quieter postgres log messages
  gem 'database_cleaner'
  gem 'vcr'
  gem 'fuubar'
  gem 'poltergeist'  # Requires PhantomJS >= 1.8.1
  gem 'cucumber'
  gem 'cucumber-rails',       :require => false
  gem 'fuubar-cucumber',      :git => 'git://github.com/martinciu/fuubar-cucumber.git'
  gem 'webmock',              '~> 1.9.0'
  gem 'selenium-client'
  gem 'capybara'
  gem 'launchy'
  gem 'spork'
end
