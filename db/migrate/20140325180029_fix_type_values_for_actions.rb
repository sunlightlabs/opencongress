class FixTypeValuesForActions < ActiveRecord::Migration
  def self.up
    Action.update_all({:type => 'AmendmentAction'}, 'type is null and amendment_id is not null')
    Action.update_all({:type => 'BillAction'}, 'type is null and amendment_id is null and bill_id is not null')
  end

  def self.down
  end
end
