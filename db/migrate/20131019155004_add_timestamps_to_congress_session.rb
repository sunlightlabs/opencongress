class AddTimestampsToCongressSession < ActiveRecord::Migration
  def self.up
    change_table :congress_sessions do |t|
      t.timestamps
    end
    CongressSession.order("date desc").first.touch rescue nil
  end

  def self.down
    remove_column :congress_sessions, :created_at
    remove_column :congress_sessions, :updated_at
  end
end
