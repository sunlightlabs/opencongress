OpenCongress::Application.configure do
  config.cache_classes = true
  config.action_controller.perform_caching = true
  config.cache_store = :mem_cache_store, 'localhost:11211', { :namespace => 'opencongress_staging' }

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.serve_static_assets = true

  config.assets.compress = true
  config.assets.js_compressor  = :uglifier
  config.assets.digest = true
  config.eager_load = true
  
  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = false
  #config.action_mailer.delivery_method = :postmark
  #config.action_mailer.default_url_options = {
  #  :host => 'staging.opencongress.org'
  #}

  config.faxable.deliver_faxes = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  Paperclip.options[:command_path] = "/usr/local/bin"

  ## removed when switched to rails 3.  still necessary??
  # if defined?(PhusionPassenger)
  #     PhusionPassenger.on_event(:starting_worker_process) do |forked|
  #         if forked
  #             # We're in smart spawning mode.
  #             Rails.cache.instance_variable_get(:@data).reset
  #         else
  #             # We're in conservative spawning mode. We don't need to do anything.
  #         end
  #     end
  # end
end
