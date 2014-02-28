require 'active_support/dependencies'
require 'pluggable_loader/configuration'
require 'pluggable_loader/loader'

# PluggableLoader is an extension for ActiveSupport::Dependencies,
# which allows engines to override the main app's core classes.
module PluggableLoader
end

# allow whitelisted 'pluggables' to reopen core classes
module ActiveSupport::Dependencies
  def pluggable_loader
    @pluggable_loader ||= PluggableLoader::Loader.new
  end

  alias_method :require_or_load_without_multiple, :require_or_load
  def require_or_load(file_name, const_path = nil)
    require_or_load_without_multiple(file_name, const_path)
    pluggable_loader.require_or_load_from_pluggables(file_name) do |engine_file|
      require_or_load_without_multiple(file_name, const_path)
    end
  end
end

# patch `view_paths` to include pluggable engines
module AbstractController::ViewPaths
  def self.included(cls)
    cls.view_paths = ["#{Rails.root}/app/views"].tap do |paths|
      ActiveSupport::Dependencies.pluggable_loader.engine_paths.each do |path|
        paths << "#{path}/app/views"
      end
    end
  end
end

# Let pluggables be required without knowing the gem path
def require_pluggable(requirement, params)
  require ActiveSupport::Dependencies.pluggable_loader.pluggable_path_for(requirement, params[:from])
end

def require_pluggable_dependency(requirement, params)
  require_dependency ActiveSupport::Dependencies.pluggable_loader.pluggable_path_for(requirement, params[:from])
end