class PopulateAmendmentCongressField < ActiveRecord::Migration
  def self.up
    # This is Postgres-specific syntax. Rails 3.0 does not support UPDATE-with-JOIN for Postgres.
    execute "UPDATE amendments SET congress = bills.session FROM bills WHERE amendments.bill_id = bills.id;"
  end

  def self.down
    Amendment.update_all(:congress => nil)
  end
end
