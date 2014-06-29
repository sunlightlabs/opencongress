class InitialSchema < ActiveRecord::Migration
  def self.up
    unless Rails.env.production?
      abcs = ActiveRecord::Base.configurations
      ENV['PGHOST']     = abcs[Rails.env]["host"] if abcs[Rails.env]["host"]
      ENV['PGPORT']     = abcs[Rails.env]["port"].to_s if abcs[Rails.env]["port"]
      ENV['PGUSER']     = abcs[Rails.env]["username"].to_s if abcs[Rails.env]["username"]
      ENV['PGPASSWORD'] = abcs[Rails.env]["password"].to_s if abcs[Rails.env]["password"]
      db = ActiveRecord::Base.configurations[Rails.env]['database']
      success = system("psql -d #{db} -f #{Rails.root + 'db/migrate/initial_schema.sql'}")

      raise 'Error importing schema' unless success
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
