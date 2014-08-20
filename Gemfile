source 'http://rubygems.org'

gem 'rails', '= 3.1.3'
gem 'rake', '~> 0.9.1'

gem 'thin'

# database gems -- need both pg and mysql for app and wiki
gem 'pg'

gem "settingslogic"

gem 'titlecase'

# HAML support
gem "haml", "~> 3.1.8"
gem "haml-rails"

group :assets do
  gem 'coffee-rails', '~> 3.1.1'
  gem 'uglifier', '>= 1.0.3'
end

gem 'sass-rails', '~> 3.1.5'
gem 'jquery-rails'
gem 'prototype-rails' #should be removed eventually

# RABL for API / JSON
gem 'rabl', "~> 0.2.8"

# Background tasks
gem 'delayed_job', '~> 2.1'

# RMagick
gem 'rmagick', '~> 2.13.1', :require => "RMagick"
gem "galetahub-simple_captcha", '0.1.3', :require => "simple_captcha"

# Image uploads
gem 'carrierwave'
gem 'fog'

gem "awesome_nested_set", ">= 2.0"

gem 'curb'

gem 'postmark-mitt'

# Sunlight Foundation Congress API v3
gem "congress", :git => "git://github.com/drinks/congress.git" , :branch => "allow-string-zipcodes"  #">= 0.2.0"

# jammit support
gem "jammit"
gem "closure-compiler"

# paperclip -- for attaching files to requests
gem 'paperclip'

# Deal with unicode strings
gem 'unicode_utils'

# Geocoding users on create
gem 'geocoder', :git => 'git://github.com/sunlightlabs/geocoder.git'

# Split names for first/last support
gem 'full-name-splitter'
# And determine their gender
gem 'sexmachine'

# OpenID
gem 'ruby-openid'
gem 'rack-openid'

# JSONP middleware
gem 'rack-contrib'

# memcache
gem 'memcache-client'
gem 'beanstalk-client'

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

# spam protection
gem 'rakismet'

# oauth
gem 'oauth'
gem 'facebooker2'

gem 'will_paginate', '~> 3.0.pre2'

gem "validates_captcha"
gem "okkez-open_id_authentication"

gem 'acts-as-taggable-on', '~> 2.3.3'

gem 'simple_form'

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

gem 'awesome_print'

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
  gem 'debugger'
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
