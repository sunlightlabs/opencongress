require 'o_c_logger'
require 'unitedstates'

$latest_congress = Settings.available_congresses.sort.last

['historical', 'current'].each do |mode|
  cmtes_file_path = File.join(Settings.data_path,
                              "congress-legislators",
                              "committees-#{mode}.yaml")
  cmtes = YAML.load_file(cmtes_file_path)
  cmtes.each do |cmte_hash|
    UnitedStates::Committees.import_committee cmte_hash
  end
end
