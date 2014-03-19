namespace :db do
  desc 'Create YAML test fixtures from data in an existing database.  
  Defaults to development database. Set Rails.env to override.'

  task :extract_fixtures => :environment do
    sql = 
    
    if ENV['IDS'] 
      sql = "SELECT * FROM %s WHERE id IN (#{ENV['IDS']})"  
    elsif ENV['WHERE']
      sql = "SELECT * FROM %s WHERE #{ENV['WHERE']}"  
    else
      sql = "SELECT * FROM %s"
    end
    
    skip_tables = ["schema_info", "sessions"]
    ActiveRecord::Base.establish_connection
    tables = ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : ActiveRecord::Base.connection.tables - skip_tables
    tables.each do |table_name|
      i = "000"
      File.open("#{Rails.root}/db/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        file.write data.inject({}) { |hash, record|
          hash["#{table_name}_#{i.succ!}"] = record
          hash
        }.to_yaml
      end
    end
  end

  desc "Update a fixture by adding the named bills. e.g. rake db:extract_bills_fixtures listed_in=bills.txt output_to=bills.yml"
  task :extract_bills_fixtures => :environment do
    if ENV['listed_in'] && File.exists?(ENV['listed_in'])
      ident_list = File.read(ENV['listed_in']).split(/[\r\n]+/)
    elsif ENV['bills']
      ident_list = ENV['bills'].split(/,/)
    else
      puts "You must specify a file with listed_in= or a comma-separated list of bill idents with bills="
      next
    end

    if ENV['output_to'].nil?
      puts "You must specify a file with output_to="
      next
    end

    bills = Hash.new
    ident_list.each do |ident|
      b = Bill.find_by_ident(ident)
      if b.nil?
        puts "Could not find #{ident}"
      else
        bills[b.ident] = b
      end
    end

    if File.exists?(ENV['output_to'])
      open(ENV['output_to'], 'r') do |instream|
        bills.update(YAML::load(instream))
      end
    end

    open(ENV['output_to'], 'w') do |outstream|
      YAML::dump(bills, outstream)
    end
  end
end
