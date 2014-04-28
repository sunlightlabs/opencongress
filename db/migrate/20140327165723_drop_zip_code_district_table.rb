class DropZipCodeDistrictTable < ActiveRecord::Migration
  def self.up
    drop_table :zipcode_districts
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration.new("ZIP Code data is not available to populate the ZipCodeDistrict table.")
  end
end
