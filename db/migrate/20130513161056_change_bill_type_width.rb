class ChangeBillTypeWidth < ActiveRecord::Migration
  @@govtrack_to_thomas = [
    ["hc", "hconres"],
    ["hr", "hres"],     # It's paramount that we convert hr => hres before
    ["h", "hr"],        # converting h => hr, else we would map both to hres
    ["hj", "hjres"],
    ["sj", "sjres"],
    ["sc", "sconres"],
    ["sr", "sres"]
    # We can ignore "s" to "s"
  ]

  def self.up
    change_column :bills, :bill_type, :string, :limit => 7

    @@govtrack_to_thomas.each do |govtrack_abbr, thomas_abbr|
      Bill.where(:bill_type => govtrack_abbr).each do |bill|
        bill.bill_type = thomas_abbr
        bill.save!
      end
    end
  end

  def self.down
    @@govtrack_to_thomas.each do |govtrack_abbr, thomas_abbr|
      Bill.where(:bill_type => thomas_abbr).each do |bill|
        bill.bill_type = govtrack_abbr
        bill.save!
      end
    end

    change_column :bills, :bill_type, :string, :limit => 2
  end
end
