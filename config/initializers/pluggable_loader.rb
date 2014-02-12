require 'pluggable_loader'

PluggableLoader.configure do |config|
  config.whitelist = %W(formageddon)
end