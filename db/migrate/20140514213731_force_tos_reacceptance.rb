class ForceTosReacceptance < ActiveRecord::Migration
  def self.up
    User.authorized.update_all(:status => 3)
  end

  def self.down
    User.where(:status => 3).update_all(:status => 1)
  end
end
