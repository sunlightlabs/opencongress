module PluggableLoader
  class Loader
    # Returns a list of paths to loaded engines.
    def engine_paths
      @engine_paths ||= Rails::Application::Railties.engines.collect{ |engine| engine.config.root.to_s }
    end

    # Returns a list of paths to loaded plugins.
    def pluggable_paths
      @pluggable_paths ||= engine_paths.find_all do |path|
        path =~ /(#{Regexp.quote(PluggableLoader.config.whitelist.join('|'))})/
      end
    end

    def require_or_load_from_pluggables(file_name, &block)
      relative_name = file_name.gsub(Rails.root.to_s, '')
      pluggable_paths.each do |path|
        engine_file = File.join(path, relative_name)
        yield engine_file if File.file?(engine_file)
      end
    end

    def pluggable_path_for(requirement, pluggable)
      pattern = /#{Regexp.quote(pluggable)}(-[0-9a-f\.]+)?$/
      File.expand_path(
        requirement,
        pluggable_paths.select{|p| (p =~ pattern).present?}.first)
    end
  end
end