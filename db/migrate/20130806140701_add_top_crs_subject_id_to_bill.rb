class AddTopCrsSubjectIdToBill < ActiveRecord::Migration
  def self.up
    add_column :bills, :top_subject_id, :integer
  end

  def self.down
    remove_column :bills, :top_subject_id
  end
end
