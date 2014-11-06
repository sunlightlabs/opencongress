class AddSessionToRollCall < ActiveRecord::Migration

  def self.up

    change_table :roll_calls do |t|
      t.integer :session
    end

    RollCall.all.each do |rc|
      rc.session = rc.congress
      rc.save
    end

  end

  def self.down
    change_table :roll_calls do |t|
      t.remove :session
    end
  end

end