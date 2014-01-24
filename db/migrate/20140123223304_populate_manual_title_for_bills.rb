class PopulateManualTitleForBills < ActiveRecord::Migration
  def self.up
    default_titles = BillTitle.where(:is_default => true).to_a
    default_titles.each do |bill_title|
      bill = Bill.find(bill_title.bill_id)
      bill.manual_title = bill_title.title
      bill.save!
    end
  end

  def self.down
    Bill.update_all({:manual_title => nil}, 'manual_title IS NOT NULL')
  end
end
