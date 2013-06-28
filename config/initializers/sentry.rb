begin
  require 'raven'
  Raven.configure do |config|
    config.dsn = ApiKeys.sentry_dsn
  end
rescue nil
end