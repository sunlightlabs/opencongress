source 'http://rubygems.org'

gem 'activemodel', '~> 4.1.0'

gem 'rails', '~> 4.1.0'
gem 'rake', '~> 0.9.1'

gem 'railties'
gem 'thin'
gem 'dalli'
gem 'rails-observers'

# database gems -- need both pg and mysql for app and wiki
gem 'pg'
# gem 'mysql2'

# documentation generation tool
gem 'yard'

gem "settingslogic"

# user notification system
gem 'public_activity'

gem 'titlecase'

# HAML support
gem "haml"
gem "haml-rails"

gem 'coffee-rails', '>= 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'sass-rails', '>= 4.0.0'
gem 'bourbon'

gem 'actionpack-page_caching'

#group :assets do
#  gem 'coffee-rails'
#  gem 'uglifier', '>= 1.0.3'
#end

gem 'jquery-rails'
# gem 'prototype-rails' #should be removed eventually

# RABL for API / JSON
gem 'rabl'

# Background tasks
gem 'delayed_job'#, '~> 3.1'
gem 'sidekiq'

# RMagick
gem 'rmagick', '~> 2.13.1', :require => "RMagick"
gem 'simple_captcha2', require: 'simple_captcha'
#gem "galetahub-simple_captcha", '0.1.3', :require => "simple_captcha"

# Image uploads
gem 'carrierwave'
gem 'fog'

gem 'delayed_job_active_record'
gem "awesome_nested_set", ">= 2.0"

#Rails transition gems
gem "acts_as_tree", "~>2.0.0"
gem 'prototype_legacy_helper', '0.0.0', :git => 'git://github.com/rails/prototype_legacy_helper.git'

gem 'curb'

gem 'postmark-mitt'

# Sunlight Foundation Congress API v3
gem "congress", :git => "git://github.com/drinks/congress.git" , :branch => "allow-string-zipcodes"  #">= 0.2.0"

# jammit support
# gem "jammit"
gem "closure-compiler"

# paperclip -- for attaching files to requests
gem "paperclip", "~> 4.1"

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
gem "open_id_authentication"

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

gem 'will_paginate'

gem "validates_captcha"

gem 'acts-as-taggable-on'

gem 'simple_form'

# Mail
gem 'mechanize'
gem 'formageddon', '~> 0.0.2', :git => 'git://github.com/sunlightlabs/formageddon.git', :branch => "beta"
gem 'postmark-rails'
# Faxing
gem 'phaxio'
# apt-get or brew `install xvfb wkhtmltopdf` first!
# You'll have to build QT yourself on Ubuntu: https://code.google.com/p/wkhtmltopdf/wiki/compilation
gem 'pdfkit'

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
  gem 'byebug'
  gem 'annotate',             '>=2.6.0'
  gem 'pry'
  gem 'pry-nav'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
  gem 'pry-byebug'
  gem 'rails_best_practices'
  gem 'simplecov',            :require => false
  gem 'guard'
  gem 'guard-livereload'
  gem 'rack-mini-profiler'
  gem 'rspec-rails'
  gem 'random_data'
  gem 'factory_girl_rails'
end

group :test do
  gem 'silent-postgres'  # Quieter postgres log messages
  gem 'database_cleaner'
  gem 'vcr'
  gem 'fuubar'
  gem 'poltergeist'  # Requires PhantomJS >= 1.8.1
  gem 'cucumber-rails', :require => false
  gem 'fuubar-cucumber',      :git => 'git://github.com/martinciu/fuubar-cucumber.git'
  gem 'webmock',              '~> 1.9.0'
  gem 'selenium-webdriver'
  gem 'capybara'
  gem 'launchy'
  gem 'spork'
end
