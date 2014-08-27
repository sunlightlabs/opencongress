class AddDataColumnToNotebookItems < ActiveRecord::Migration
  def self.up
    add_column :notebook_items, :data, :text
  end

  def self.down
    remove_column :notebook_items, :data
  end
end
