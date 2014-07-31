namespace :spec do
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
      File.open("#{Rails.root}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        file.write data.inject({}) { |hash, record|
          hash["#{table_name}_#{i.succ!}"] = record
          hash
        }.to_yaml
      end
    end
  end

  task :generate_congress_fixtures => :environment do
    congress_number = Settings.available_congresses.sort.last
    STDOUT.puts "Do you want to update your development database's legislators " \
    "before updating your test database? (y/n)"
    input = STDIN.gets.strip
    if input.downcase[0] == "y" 
      ImportLegislatorsJob.import_congress(congress_number)
    end
    senate = Person.list_chamber("sen", congress_number, "lastname asc")
    rep = Person.list_chamber("rep", congress_number, "lastname asc")
    people_hash = {}
    roles_hash = {}
    [senate + rep].flatten.each do |record|
      #list_chamber grabs unnecessary stuff that we don't want in fixtures
      extraneous_keys = record.attributes.keys - Person.new.attributes.keys
      person_attributes = record.attributes.except(*extraneous_keys)
      people_hash["person_#{record.id}"] = person_attributes
      record.roles.each do |role|
        role_attributes = role.attributes.merge(
          "person" => "person_#{record.id}"
        )
        role_attributes = role_attributes.except("person_id", "id")
        roles_hash["roles_#{role.id}"] = role_attributes
      end
    end
    
    puts "Writing people fixtures..."
    File.open("#{Rails.root}/test/fixtures/people.yml", "w").write(people_hash.to_yaml)
    puts "Writing role fixtures..."
    File.open("#{Rails.root}/test/fixtures/roles.yml", "w").write(roles_hash.to_yaml)
    puts "Done!"
  end

  desc "Update a fixture by adding the named bills. e.g. rake spec:extract_bills_fixtures listed_in=bills.txt output_to=bills.yml"
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
