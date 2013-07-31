class UpdateFormageddonFields < ActiveRecord::Migration
  def self.up
    add_column :formageddon_forms, :submit_css_selector, :string
    add_column :formageddon_form_fields, :css_selector, :string
  end

  def self.down
    remove_column :formageddon_forms, :submit_css_selector
    remove_column :formageddon_form_fields, :css_selector
  end
end
