require 'pluggable_loader'

# Add external dependency names to the "whitelist" field if you wish to
# modify them (monkey patch) in the application.
PluggableLoader.configure do |config|
  config.whitelist = %W(formageddon public_activity)
end