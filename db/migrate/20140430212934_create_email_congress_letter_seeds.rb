class CreateEmailCongressLetterSeeds < ActiveRecord::Migration
  def self.up
    create_table :email_congress_letter_seeds do |t|
      t.text :raw_source

      t.string :sender_email, :limit => 255
      t.string :sender_title, :limit => 255
      t.string :sender_first_name, :limit => 255
      t.string :sender_last_name, :limit => 255
      t.string :sender_street_address, :limit => 255
      t.string :sender_street_address_2, :limit => 255
      t.string :sender_city, :limit => 255
      t.string :sender_state, :limit => 255
      t.string :sender_zipcode, :limit => 255
      t.string :sender_zip_four, :limit => 255
      t.string :sender_mobile_phone, :limit => 255

      t.string :email_subject, :limit => 255
      t.text :email_body

      t.boolean :resolved, :default => false
      t.datetime :resolved_at
      t.string :resolution
      t.string :confirmation_code, :limit => 255

      t.timestamps
    end
  end

  def self.down
    drop_table :email_congress_letter_seeds
  end
end
