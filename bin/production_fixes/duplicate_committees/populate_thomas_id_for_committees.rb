cmtes = YAML.load_file(File.join(Settings.unitedstates_legislators_clone_path, 'committees-historical.yaml'))

def serial_comma_apocalypse (name)
  with_comma = name.gsub(/(\w) and/, '\1, and')
  without_comma = name.gsub(/, and/, ' and')
  [with_comma, without_comma]
end

def assign_thomas_id_to_all (chamber, thomas_id, comms)
  if chamber == 'house'
    comms.select! {|comm| not comm.name.downcase.starts_with? 'senate'}
  elsif chamber == 'senate'
    comms.select! {|comm| not comm.name.downcase.starts_with? 'house'}
  end

  comms.each do |comm|
    comm.thomas_id = thomas_id
    comm.save!
  end
end

Committee.update_all("subcommittee_name = NULL", "subcommittee_name = ''")

cmtes.each do |cmte|
  chamber = cmte['type'].capitalize
  alt_names = cmte.fetch('names', []).map{|cong, altname| altname}
  cmte_names = [cmte['name']].concat(alt_names)
  cmte_name_variations = cmte_names.flat_map do |name|
    with_comma, without_comma = serial_comma_apocalypse(name)

    [ with_comma,
      without_comma,
      "#{chamber} #{with_comma}",
      "#{chamber} #{without_comma}"
    ]
  end
  comms = Committee.where(:name => cmte_name_variations,
                          :subcommittee_name => nil,
                          :thomas_id => nil)
  observed_comm_names = comms.map{|c| c.name}
  assign_thomas_id_to_all(cmte['type'], cmte['thomas_id'], comms)

  (cmte['subcommittees'] or []).each do |subcmte|
    sub_alt_names = subcmte.fetch('names', []).map{|cong, altname| altname}
    subcmte_names = [subcmte['name']].concat(sub_alt_names)
    subcmte_name_variations = subcmte_names.flat_map do |name|
      serial_comma_apocalypse(name)
    end
    subcomms = Committee.where(:subcommittee_name => subcmte_name_variations,
                               :thomas_id => nil)
    assign_thomas_id_to_all(cmte['type'], "#{cmte['thomas_id']}#{subcmte['thomas_id']}", subcomms)
  end
end


files = ['manual_committee_id_to_thomas_id.csv']
files.each do |file|
  path = File.join(File.dirname(__FILE__), file)
  if File.exists? path
    CSV.foreach(path) do |row|
      cmte_id, thomas_id = row
      cmte = Committee.find cmte_id
      cmte.thomas_id = thomas_id
      cmte.save!
    end
  else
    raise "No such file: #{path}"
  end
end


total_cnt = Committee.count
missing_cnt = Committee.where(:thomas_id => nil).count
if missing_cnt > 0
  puts "#{missing_cnt} of #{total_cnt} Committee objects are missing a value for 'thomas_id'."
  puts "Delete them? (enter 'YES' to delete them)"
  resp = gets.strip
  if resp == "YES"
    Committee.where(:thomas_id => nil).each do |cmte|
      cmte.destroy
    end
  else
    puts "Fine, you deal with them!"
  end
end


