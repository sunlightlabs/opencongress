module PluggableLoader
  class Configuration
    attr_accessor :whitelist

    def initialize(opts={})
      self.whitelist = opts.fetch(:whitelist, [])
    end
  end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config) if block_given?
    end

    def logger
      Rails.logger
    end
  end
end