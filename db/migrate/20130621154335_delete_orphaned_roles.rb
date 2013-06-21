class DeleteOrphanedRoles < ActiveRecord::Migration
  def self.up
    Role.where(:person_id => nil).delete_all
  end

  def self.down
  end
end
