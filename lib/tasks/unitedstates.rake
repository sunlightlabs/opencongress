namespace :unitedstates do
  desc "Enumerates bill IDs for a given congress and/or bill type."
  task :enum_bills => :environment do
    cong_num = ENV['CONGRESS'] || Settings.available_congresses.sort.last
    bill_type = ENV['BILL_TYPE'] || '*'

    bill_file_paths = Dir.glob(File.join(Settings.unitedstates_data_path,
                                         cong_num.to_s,
                                         'bills',
                                         bill_type,
                                         '*'))
    bill_file_paths.sort_by! { |path| [path.length, path] }

    bill_file_paths.each do |path|
      puts "#{File.basename(path)}-#{cong_num}"
    end
  end
end

