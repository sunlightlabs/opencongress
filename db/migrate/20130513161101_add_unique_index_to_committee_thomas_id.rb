class AddUniqueIndexToCommitteeThomasId < ActiveRecord::Migration
  def self.up
    dups = Committee.group(:thomas_id).count.select{|thomas_id, cnt| cnt > 1}.sort_by{|thomas_id, cnt| cnt}.reverse
    dups.each do |thomas_id, cnt|
      cmtes = Committee.where(:thomas_id => thomas_id).order(:id).to_a
      best = cmtes.shift
      cmtes.each do |cmte|
        puts "Folding committee #{cmte.id} into committee #{best.id}"

        bmark_cnt = cmte.bookmarks.count
        if bmark_cnt > 0
          cmte.bookmarks.each do |bmark|
            unless best.bookmarks.where(:user_id => bmark.user_id).any?
              puts "Reassigning bookmark #{bmark.id} from committee #{cmte.id} to committee #{best.id}"
              best.bookmarks << bmark
              bmark.save!
            end
          end
        end

        bill_cnt = cmte.bills.count
        if bill_cnt > 0
          cmte.bills.each do |bill|
            unless best.bills.exists? bill
              puts "Reassigning bill #{bill.id} from committee #{cmte.id} to committee #{best.id}"
              best.bills << bill
              bill.save!
            end
          end
        end

        rpt_count = cmte.reports.count
        if rpt_count > 0
          cmte.reports.each do |rpt|
            unless best.reports.exists? rpt
              puts "Reassigning report #{rpt.id} from committee #{cmte.id} to committee #{best.id}"
              best.reports << rpt
              rpt.save!
            end
          end
        end

        ppl_count = cmte.people.count
        if ppl_count > 0
          cmte.people.each do |leg|
            unless best.people.exists? leg
              puts "Reassigning person #{leg.id} from committee #{cmte.id} to committee #{best.id}"
              best.people << leg
              leg.save!
            end
          end
        end

        mtg_count = cmte.meetings.count
        if mtg_count > 0
          cmte.meetings.each do |mtg|
            unless best.meetings.exists? mtg
              puts "Reassigning meeting #{mtg.id} from committee #{cmte.id} to committee #{best.id}"
              best.meetings << mtg
              mtg.save!
            end
          end
        end

        cmte.destroy
      end
    end

    add_index :committees, :thomas_id, :unique => true
  end

  def self.down
    remove_index :committees, :thomas_id
  end
end

