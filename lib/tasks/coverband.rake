# require 'coverband'

# Coverband.configure do |config|
#   config.redis             = Redis.new
#   # merge in lines to consider covered manually to override any misses
#   # existing_coverage = {'./cover_band_server/app.rb' => Array.new(31,1)}
#   # JSON.parse(File.read('./tmp/coverband_baseline.json')).merge(existing_coverage)
#   config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
#   config.root_paths        = ['/app/']
#   config.ignore            = ['vendor']
# end

# desc "report unused lines"
# task :coverband => :environment do
#   baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))

#   root_paths = ['/app/']
#   coverband_options = {:existing_coverage => baseline, :roots => root_paths}
#   Coverband::Reporter.report#(Redis.new, coverband_options)
# end

# desc "get coverage baseline"
# task :coverband_baseline do
#   Coverband::Reporter.baseline {
#     #rails
#     require File.expand_path("../../../config/environment", __FILE__)
#     #sinatra
#     #require File.expand_path("./app", __FILE__)
#   }
# end
