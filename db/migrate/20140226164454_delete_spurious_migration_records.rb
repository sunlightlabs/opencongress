class DeleteSpuriousMigrationRecords < ActiveRecord::Migration
  def self.up
    execute "DELETE FROM schema_migrations WHERE LENGTH(version) < 8;"
  end
end
