class AddFormageddonRecaptchaFormAndAddFieldsToFormageddonFormCaptchaImagesAndFormageddonThreads < ActiveRecord::Migration
  def self.up
    create_table :formageddon_recaptcha_forms do |t|
      t.integer :formageddon_form_id
      t.string :url
      t.string :response_field_css_selector
      t.string :image_css_selector
      t.string :id_selector

      t.timestamps
    end

    add_column :formageddon_form_captcha_images, :formageddon_recaptcha_form_id, :integer
    add_column :formageddon_threads, :captcha_browser_state_id, :text
  end

  def self.down
    drop_table :formageddon_recaptcha_forms
    remove_column :formageddon_form_captcha_images, :formageddon_recaptcha_form_id
    remove_column :formageddon_threads, :captcha_browser_state_id
  end
end
