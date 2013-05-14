require 'o_c_logger'

# The committees file name has a "historical" suffix but is also includes current committees
# The reason we use the historical file 
cmtes_file_path = File.join(Settings.unitedstates_legislators_clone_path, 'committees-current.yaml')
cmte_members_file_path = File.join(Settings.unitedstates_legislators_clone_path, 'committee-membership-current.yaml')

[cmtes_file_path, cmte_members_file_path].each do |file_path|
  if not File.exists? cmtes_file_path
    OCLogger.log "No such file: #{file_path}"
    exit
  end
end

$latest_congress = Settings.available_congresses.sort.last


OCLogger.log "Parsing all Committees from #{cmtes_file_path}"
cmtes = YAML.load_file(cmtes_file_path)
OCLogger.log "Parsing all Committees memberships from #{cmte_members_file_path}"
$cmte_members = YAML.load_file(cmte_members_file_path)

def import_memberships_for_cmte (cmte)
  if $cmte_members.include? cmte.thomas_id
    
    members = $cmte_members[cmte.thomas_id]
    members.each do |mem|
      legislator = Person.find_by_bioguideid(mem['bioguide'])
      if legislator
        membership = CommitteePerson.find_by_person_id_and_committee_id(legislator.id,
                                                                        cmte.id)
        if membership
          OCLogger.log "Updating membership of #{legislator.id} in committee #{cmte.thomas_id}"
        else
          OCLogger.log "Adding legislator #{legislator.id} to committee #{cmte.thomas_id}"
          membership = CommitteePerson.create :committee_id => cmte.id,
                                              :person_id => legislator.id
        end

        membership.role = mem['title']
        membership.session = $latest_congress
        membership.save!
      end

    end
  else
    OCLogger.log "No membership data for #{cmte.thomas_id} committee."
  end
end

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
  import_memberships_for_cmte cmte_rec

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
      import_memberships_for_cmte sub_cmte_rec
    end
  end
end

