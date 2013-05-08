source 'http://rubygems.org'

gem 'rails', '~> 3.0.19'
gem 'rake', '~> 0.9.1'

# database gems -- need both pg and mysql for app and wiki
gem 'pg'
gem 'mysql'

gem "settingslogic"

# HAML support
gem "haml", "~> 3.1.8"
gem "haml-rails"
# gem "sass-rails"  #<= after upgrading past rails 3.1

# RABL for API / JSON
gem 'rabl'

# Background tasks
gem 'delayed_job', '~> 2.1'

# RMagick
gem 'rmagick', '2.13.1'
gem "galetahub-simple_captcha", '0.1.3', :require => "simple_captcha"

# Image uploads
gem 'carrierwave'
gem 'fog'

gem "awesome_nested_set", ">= 2.0"

# GovKit
gem "govkit", :git => "git@github.com:sunlightlabs/govkit.git"

# jammit support
gem "jammit"
gem "closure-compiler"

# paperclip -- for attaching files to requests
gem 'paperclip'


# notifier for production errors
gem "airbrake"
gem "xray", :require => "xray/thread_dump_signal_handler"

# OpenID
gem 'ruby-openid'
gem 'rack-openid'

# JSONP middleware
gem 'rack-contrib'

# memcache
gem 'memcache-client'

# markup tools and parsers
gem 'simple-rss'
gem 'mediacloth'
gem 'hpricot'
gem 'RedCloth'
gem 'bluecloth'
gem 'htmlentities'
gem "json"
gem "nokogiri"

# spam protection
gem "defensio", :git => 'git://github.com/drinks/defensio-ruby.git'  # this forces :json api format
gem "defender"

group :deployment do
  gem 'capistrano'
  gem 'capistrano-ext'
end

# new relic RPM
gem 'newrelic_rpm'

# oauth
gem 'oauth'
gem 'facebooker2'

gem 'will_paginate', '~> 3.0.pre2'

gem "validates_captcha"
gem "okkez-open_id_authentication"

gem 'acts-as-taggable-on', '~> 2.3.3'

gem 'mechanize'
gem 'formageddon', :git => 'git://github.com/opencongress/formageddon.git'


group :test, :development do
  gem 'autotest'
  gem 'silent-postgres'	# Quieter postgres log messages
  gem 'database_cleaner'

  gem 'rspec-rails', '~> 2.4'
  gem 'fuubar'
  gem 'cucumber'
  gem 'cucumber-rails',         :require => false
  gem 'webrat'
  gem 'selenium-client'

  gem 'capybara'

  gem 'guard'
  gem 'guard-livereload'

  gem 'pry-rescue'
  gem 'pry-stack_explorer'

  gem 'rails_best_practices'
  gem 'simplecov', :require => false
end

