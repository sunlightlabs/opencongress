class UpdateMailngOnUserAudit < ActiveRecord::Migration
  def self.up
    change_table :user_audits do |t|
      t.rename :mailing, :opencongress_mail
    end
  end

  def self.down
    change_table :user_audits do |t|
      t.rename :opencongress_mail, :mailing
    end
  end
end
