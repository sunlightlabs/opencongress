require 'active_support/dependencies'

# PluginsLoader is an extension for ActiveSupport::Dependencies module,
# which allows engines to override main app's core classes.
class PluginsLoader
  # Returns list of paths to loaded engines.
  def engine_paths
    @engine_paths ||= defined?(Formageddon) ? [`bundle show formageddon`.strip] : []
    @engine_paths ||= Rails::Application.railties.engines.collect{ |engine| engine.config.root.to_s }
  end

  # Returns list of paths to loaded plugins.
  def plugin_paths
    @plugin_paths ||= engine_paths.find_all do |path|
      path =~ /(formageddon)/
    end
  end

  def require_or_load_from_plugins(file_name, &block)
    relative_name = file_name.gsub(Rails.root.to_s, '')
    plugin_paths.each do |path|
      engine_file = File.join(path, relative_name)
      yield engine_file if File.file?(engine_file)
    end
  end
end

# allow whitelisted 'plugins' to reopen core classes
module ActiveSupport::Dependencies
  def plugins_loader
    @plugins_loader ||= PluginsLoader.new
  end

  alias_method :require_or_load_without_multiple, :require_or_load
  def require_or_load(file_name, const_path = nil)
    require_or_load_without_multiple(file_name, const_path)
    plugins_loader.require_or_load_from_plugins(file_name) do |engine_file|
      require_or_load_without_multiple(file_name, const_path)
    end
  end
end