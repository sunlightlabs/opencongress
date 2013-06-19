class RemoveFedOccEmpFromCrpContribIndividualToCandidate < ActiveRecord::Migration
  def self.up
    remove_column :crp_contrib_individual_to_candidate, :fed_occ_emp
  end

  def self.down
    add_column :crp_contrib_individual_to_candidate, :fed_occ_emp, :string
  end
end
