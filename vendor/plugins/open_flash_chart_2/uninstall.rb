puts "Removing files from public directory:"
FileUtils.rm "#{::Rails.root.to_s}/public/javascripts/swfobject.js"
FileUtils.rm "#{::Rails.root.to_s}/public/open-flash-chart.swf"
puts "Plugin uninstalled."
