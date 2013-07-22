module Faxable
  class Configuration
    attr_accessor :deliver_faxes

    def initialize(opts={})
      self.deliver_faxes = opts.fetch(:deliver_faxes, true)
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