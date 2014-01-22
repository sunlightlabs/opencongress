begin
  require 'raven'
  Raven.configure do |config|
    config.dsn = ApiKeys.sentry_dsn
    config.current_environment = Rails.env
  end
rescue nil
end