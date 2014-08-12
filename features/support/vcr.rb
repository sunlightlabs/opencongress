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
  config.filter_sensitive_data("<TEXAS_AM_API_KEY>") { ApiKeys.texas_am_api_key }
  config.filter_sensitive_data("<TWITTER_CONSUMER_KEY>") { ApiKeys.twitter_consumer }
  config.filter_sensitive_data("<TWITTER_SECRET_KEY>") { ApiKeys.twitter_secret }
  config.filter_sensitive_data("<TECHNORATI_API_KEY>") { ApiKeys.technorati_api_key }
  config.filter_sensitive_data("<DAYLIFE_ACCESS_KEY>") { ApiKeys.daylife_access_key }
  config.filter_sensitive_data("<DAYLIFE_SECRET_KEY>") { ApiKeys.daylife_secret }
  config.filter_sensitive_data("<BING_KEY>") { ApiKeys.bing }
  config.filter_sensitive_data("<MAPLIGHT_KEY>") { ApiKeys.maplight }
  config.filter_sensitive_data("<WIKI_PASS_KEY>") { ApiKeys.wiki_pass }
  config.filter_sensitive_data("<WIKI_KEY_KEY>") { ApiKeys.wiki_key }
  config.filter_sensitive_data("<WIKI_CALLBACK_KEY>") { ApiKeys.wiki_callback_key }
  config.filter_sensitive_data("<GOOGLE_MAPS_KEY>") { ApiKeys.google_maps }
  config.filter_sensitive_data("<SENTRY_DSN_KEY>") { ApiKeys.sentry_dsn }
  config.filter_sensitive_data("<POSTMARK_KEY>") { ApiKeys.postmark }
  config.filter_sensitive_data("<FORMAGEDDON_PASSWORD_KEY>") { ApiKeys.formageddon_password }
  config.filter_sensitive_data("<FORMAGEDDON_GET_REPLIES_KEY>") { ApiKeys.formageddon_get_replies_key }
  config.filter_sensitive_data("<PHAXIO_KEY>") { ApiKeys.phaxio_key }
  config.filter_sensitive_data("<PHAXIO_SECRET_KEY>") { ApiKeys.phaxio_secret }
  config.filter_sensitive_data("<BSD_KEY>") { ApiKeys.bsd }
  config.filter_sensitive_data("<FACEBOOK_APP_ID_KEY>") { ApiKeys.facebook_app_id }
  config.filter_sensitive_data("<FACEBOOK_SECRET_KEY>") { ApiKeys.facebook_secret }
  config.filter_sensitive_data("<FACEBOOK_API_KEY>") { ApiKeys.facebook_api_key }
  config.filter_sensitive_data("<SMARTY_STREETS_ID>") { ApiKeys.smarty_streets_id }
  config.filter_sensitive_data("<SMARTY_STREETS_TOKEN>") { ApiKeys.smarty_streets_token }
end

VCR.cucumber_tags do |t|
  t.tag '@vcr', use_scenario_name: true
end