class FixTypeValuesForActions < ActiveRecord::Migration
  def self.up
    Action.where('type IS NULL and amendment_id IS NOT NULL').update_all(:type => 'AmendmentAction')
    Action.where('type IS NULL and amendment_id IS NULL and bill_id IS NOT NULL').update_all(:type => 'BillAction')
  end

  def self.down
  end
end
