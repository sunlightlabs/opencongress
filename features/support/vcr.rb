require 'webmock/cucumber'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.ignore_localhost = true
  config.default_cassette_options = { :record => :new_episodes }
  config.filter_sensitive_data("<SUNLIGHT_KEY>") { ApiKeys.sunlightlabs_key }
  config.filter_sensitive_data("<BITLY_KEY>") { ApiKeys.bitly }
  config.filter_sensitive_data("<MAPQUEST_KEY>") { ApiKeys.mapquest }
  config.filter_sensitive_data("<AKISMET_KEY>") { ApiKeys.akismet }
end

VCR.cucumber_tags do |t|
  t.tag '@vcr', use_scenario_name: true
end