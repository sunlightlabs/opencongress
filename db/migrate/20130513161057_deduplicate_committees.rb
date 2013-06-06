class DeduplicateCommittees < ActiveRecord::Migration
  def self.up
    # A bug in the committee import process duplicated many committees.
    # This collapses each duplicate into the first of it's set. After this
    # we can create a foreign key constraint on the thomas_id.
    # TODO We still need to populate the thomas_id fields for the current committees.. HOW?
    dup_counts = Committee.group(:name, :subcommittee_name).count.select { |grp,cnt| cnt > 1}
    dup_counts.each do |grp, cnt|
      c_name, c_subname = grp
      cmtes = Committee.where(:name => c_name, :subcommittee_name => c_subname).order(:id).to_a
      best = cmtes.shift
      Committee.transaction do
        cmtes.each do |cmte|
          puts "Folding committee #{cmte.id} into committee #{best.id}"

          bmark_cnt = cmte.bookmarks.count
          if bmark_cnt > 0
            cmte.bookmarks.each do |bmark|
              unless best.bookmarks.where(:user_id => bmark.user_id).any?
                best.bookmarks << bmark
                bmark.save!
                puts "Reassigned bookmark #{bmark.id} from committee #{cmte.id} to committee #{best.id}"
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
    end
  end
end

