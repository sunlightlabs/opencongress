require 'o_c_logger'
require 'unitedstates'

# The committees file name has a "historical" suffix but is also includes current committees
# The reason we use the historical file 
cmtes_file_path = File.join(Settings.unitedstates_legislators_clone_path, 'committees-historical.yaml')
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

#########################


['historical', 'current'].each do |mode|
  cmtes_file_path = File.join(Settings.unitedstates_legislators_clone_path,
                              "committees-#{mode}.yaml")
  cmtes = YAML.load_file(cmtes_file_path)
  cmtes.each do |cmte_hash|
    UnitedStates::Committees.import_committee cmte_hash
  end
end
