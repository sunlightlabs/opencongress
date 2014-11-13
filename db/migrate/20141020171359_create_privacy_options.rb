class CreatePrivacyOptions < ActiveRecord::Migration

  def self.up
    create_table :user_privacy_option_items do |t|
      t.belongs_to :user, :index => true
      t.references :privacy_object, :polymorphic => true
      t.string :method, :default => nil
      t.integer :privacy, :default => 0
      t.timestamps
    end

    add_index :user_privacy_option_items, :privacy_object_id, name: 'index_user_po_id'
    add_index :user_privacy_option_items, :privacy_object_type, name: 'index_user_po_type'
  end

  def self.down
    drop_table :user_privacy_option_items
  end

end