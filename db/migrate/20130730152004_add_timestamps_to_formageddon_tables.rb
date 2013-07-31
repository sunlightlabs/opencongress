class AddTimestampsToFormageddonTables < ActiveRecord::Migration
  def self.up
    add_column :formageddon_contact_steps, :created_at, :datetime
    add_column :formageddon_contact_steps, :updated_at, :datetime
    add_column :formageddon_forms, :created_at, :datetime
    add_column :formageddon_forms, :updated_at, :datetime
    add_column :formageddon_form_fields, :created_at, :datetime
    add_column :formageddon_form_fields, :updated_at, :datetime
    add_column :formageddon_form_captcha_images, :created_at, :datetime
    add_column :formageddon_form_captcha_images, :updated_at, :datetime
  end

  def self.down
    remove_column :formageddon_contact_steps, :created_at
    remove_column :formageddon_contact_steps, :updated_at
    remove_column :formageddon_forms, :created_at
    remove_column :formageddon_forms, :updated_at
    remove_column :formageddon_form_fields, :created_at
    remove_column :formageddon_form_fields, :updated_at
    remove_column :formageddon_form_captcha_images, :created_at
    remove_column :formageddon_form_captcha_images, :updated_at
  end
end
