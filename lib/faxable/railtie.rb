require 'rails'

module Faxable
  class Railtie < Rails::Railtie
    config.faxable = ActiveSupport::OrderedOptions.new

    initializer "faxable.configure" do |app|
      Faxable.configure do |config|
        app.config.faxable.each do |key, val|
          config.send(:"#{key.to_s}=", val)
        end
      end
    end
  end
end
