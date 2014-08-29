# Use nginx for x-sendfile
ActionController::Streaming::X_SENDFILE_HEADER = 'X-Accel-Redirect'

OpenCongress::Application.configure do
  # Use a different cache store in production
  config.cache_classes = true
  config.action_controller.perform_caching = true
  config.cache_store = :mem_cache_store, 'localhost:11211', { :namespace => 'opencongress_production' }

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.serve_static_assets = false

  # Send mail with postmark
  config.action_mailer.delivery_method = :postmark
  config.action_mailer.default_url_options = { :host => "www.opencongress.org" }

  # Send faxes
  config.faxable.deliver_faxes = true

  # Enable serving of images, stylesheets, and javascripts from an asset server
  config.action_controller.asset_host = "https://d6ekjl42nohi3.cloudfront.net"

  # Use the git revision of this release
  # RELEASE_NUMBER = %x{cat REVISION | cut -c -7}.rstrip

  # Enable serving of images, stylesheets, and javascripts from CloudFront
  # config.action_controller.asset_host = Proc.new {
  #    |source, request| "#{request.ssl? ? 'https' : 'http'}://d1f0ywl7f2vxwh.cloudfront.net/r-RELEASE_NUMBER"
  # }

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Compress JavaScripts and CSS
  config.assets.compress = true
   
  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false
   
  # Generate digests for assets URLs
  config.assets.digest = true

  config.eager_load = true

   
  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH
   
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile `= %w( search.js )
   
  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  Paperclip.options[:command_path] = "/usr/local/bin"

  GC.enable_stats if defined?(GC) && GC.respond_to?(:enable_stats)
end
