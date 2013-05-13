require 'o_c_logger'

# The committees file name has a "historical" suffix but is also includes current committees
# The reason we use the historical file 
cmtes_file_path = File.join(Settings.unitedstates_legislators_clone_path, 'committees-current.yaml')
if not File.exists? cmtes_file_path
  OCLogger.log "No such file: #{cmtes_file_path}"
  exit
end

OCLogger.log "Parsing all Committees from #{cmtes_file_path}"

latest_congress = Settings.available_congresses.sort.last

cmtes = YAML.load_file(cmtes_file_path)
cmtes.each do |cmte|
 
  cmte_rec = Committee.where(:thomas_id => cmte['thomas_id']) .first
  if not cmte_rec
    cmte_rec = Committee.new :thomas_id => cmte['thomas_id']
    OCLogger.log "Adding new Committee #{cmte['thomas_id']}"
  else
    OCLogger.log "Updating Committee #{cmte['thomas_id']}"
  end
  cmte_rec.name = cmte['name']
  cmte_rec.subcommittee_name = nil
  cmte_rec.active = true
  cmte_rec.save!

  if cmte['subcommittees']
    cmte['subcommittees'].each do |sub_cmte|
      full_thomas_id = "#{cmte['thomas_id']}#{sub_cmte['thomas_id']}"
      sub_cmte_rec = Committee.where(:thomas_id => full_thomas_id) .first
      if not sub_cmte_rec
        sub_cmte_rec = Committee.new :thomas_id => full_thomas_id
        OCLogger.log "Adding new sub-Committee #{full_thomas_id}"
      else
        OCLogger.log "Updating sub-Committee #{full_thomas_id}"
      end
      sub_cmte_rec.name = cmte['name']
      sub_cmte_rec.subcommittee_name = sub_cmte['name']
      sub_cmte_rec.active = true
      sub_cmte_rec.save!
    end
  end
end

