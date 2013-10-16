class AddSpammableFieldsToNotebookItems < ActiveRecord::Migration
  def self.up
    change_table :notebook_items do |t|
      t.string  :user_agent
      t.string  :ip_address
      t.boolean :spam
      t.boolean :censored
      # t.index :spam
      # t.index :censored
    end
  end

  def self.down
    change_table :notebook_items do |t|
      t.remove :user_agent
      t.remove :ip_address
      t.remove :spam
      t.remove :censored
    end
  end
end
