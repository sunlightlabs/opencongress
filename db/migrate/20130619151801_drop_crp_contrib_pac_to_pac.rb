class DropCrpContribPacToPac < ActiveRecord::Migration
  def self.up
    drop_table :crp_contrib_pac_to_pac
  end

  def self.down
    create_table "crp_contrib_pac_to_pac", :id => false, :force => true do |t|
      t.string "cycle",                                  :null => false
      t.string "fec_trans_id",                           :null => false
      t.string "filer_osid"
      t.string "donor_name"
      t.string "filer_name"
      t.string "donor_city"
      t.string "donor_state"
      t.string "donor_zip"
      t.string "fed_occ_emp"
      t.string "donor_crp_interest_group_osid"
      t.date   "contrib_date",                           :null => false
      t.float  "amount"
      t.string "recipient_osid"
      t.string "party"
      t.string "other_id"
      t.string "recipient_type"
      t.string "recipient_crp_interest_group_osid"
      t.string "amended"
      t.string "report_type"
      t.string "election_type"
      t.string "microfilm"
      t.string "contrib_type"
      t.string "donor_realcode_crp_interest_group_osid"
      t.string "realcode_source"
    end
  end
end

