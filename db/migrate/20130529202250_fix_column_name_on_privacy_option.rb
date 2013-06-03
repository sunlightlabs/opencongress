class FixColumnNameOnPrivacyOption < ActiveRecord::Migration
  def self.up
    rename_column :privacy_options, :my_instant_messanger_names, :my_instant_messenger_names
  end

  def self.down
    rename_column :privacy_options, :my_instant_messenger_names, :my_instant_messanger_names
  end
end
