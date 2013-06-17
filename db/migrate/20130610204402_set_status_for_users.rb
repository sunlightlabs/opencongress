class SetStatusForUsers < ActiveRecord::Migration
  def self.up
    execute "update users set status = #{User::STATUSES[:active]} where is_banned = FALSE and activated_at is not NULL;"
    execute "update users set status = #{User::STATUSES[:banned]} where is_banned = TRUE;"
    execute "update users set status = #{User::STATUSES[:unconfirmed]} where activated_at is NULL;"
    remove_column :users, :is_banned
  end

  def self.down
    add_column :users, :is_banned, :boolean, :default => false
    execute "update users set is_banned = TRUE where status = #{User::STATUSES[:banned]};"
  end
end
