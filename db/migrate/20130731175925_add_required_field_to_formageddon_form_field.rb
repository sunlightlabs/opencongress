class AddRequiredFieldToFormageddonFormField < ActiveRecord::Migration
  def self.up
    add_column :formageddon_form_fields, :required, :boolean
  end

  def self.down
    add_column :formageddon_form_fields, :required
  end
end
