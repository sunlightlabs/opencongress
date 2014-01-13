require 'coverband'

Coverband.configure do |config|
  config.root              = Dir.pwd
  config.redis             = Redis.new
  config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
  config.root_paths        = ['/app/']
  config.ignore            = ['vendor']
  config.percentage        = 25.0
end

module OpenCongress
  class Application
    config.middleware.use Coverband::Middleware
  end
end