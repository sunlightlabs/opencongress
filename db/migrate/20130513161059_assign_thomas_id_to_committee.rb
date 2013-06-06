class AssignThomasIdToCommittee < ActiveRecord::Migration
  def self.up
    total_cnt = Committee.count
    missing_cnt = Committee.where(:thomas_id => nil).count
    if missing_cnt > 0
      raise [
        "\033[31m",
        "#{missing_cnt} of #{total_cnt} Committee objects are missing a value for 'thomas_id'.",
        "The next migration requires this field to be populated for all records.",
        "Hint: bin/production_fixes/duplicate_committees/populate_thomas_id_for_committees.rb",
        "\033[0m\n"
      ].join("\n")
    end
  end

  def self.down
    Committee.update_all("thomas_id = NULL")
  end
end
