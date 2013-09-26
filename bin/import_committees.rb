require 'o_c_logger'
require 'united_states'

['historical', 'current'].each do |mode|
  cmtes_file_path = File.join(Settings.data_path,
                              "congress-legislators",
                              "committees-#{mode}.yaml")
  cmtes = YAML.load_file(cmtes_file_path)
  cmtes.each do |cmte_hash|
    UnitedStates::Committees.import_committee cmte_hash
  end
end
