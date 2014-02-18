class PopulateManualTitleForBills < ActiveRecord::Migration
  def self.up
    default_titles = BillTitle.where(:is_default => true).to_a
    default_titles.each do |bill_title|
      # Using update_all to avoid save handlers since we don't have
      # update_column (added in rails 3.1)
      Bill.where(:id => bill_title.bill_id).update_all(:manual_title => bill_title.title)
    end
  end

  def self.down
    Bill.update_all({:manual_title => nil}, 'manual_title IS NOT NULL')
  end
end
