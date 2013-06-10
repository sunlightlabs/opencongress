require 'o_c_logger'
require 'unitedstates'

cmte_members_file_path = File.join(Settings.data_path,
                                   "congress-legislators",
                                   "committee-membership-current.yaml")
cmte_memberships = YAML.load_file(cmte_members_file_path)
cmte_memberships.each do |cmte_thomas_id, members|
  members.each do |mem_hash|
    UnitedStates::Committees.import_membership cmte_thomas_id, mem_hash
  end
end
