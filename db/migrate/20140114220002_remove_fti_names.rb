class RemoveFtiNames < ActiveRecord::Migration
  def self.up
    remove_column :articles, :fti_names
    remove_column :bill_fulltext, :fti_names
    remove_column :bill_titles, :fti_titles
    remove_column :commentaries, :fti_names
    remove_column :comments, :fti_names
    remove_column :committees, :fti_names
    remove_column :people, :fti_names
    remove_column :subjects, :fti_names
    remove_column :upcoming_bills, :fti_names
  end

  def self.down
    add_column :articles, :fti_names, "public.tsvector"
    add_column :bill_fulltext, :fti_names, "public.tsvector"
    add_column :bill_titles, :fti_titles, "public.tsvector"
    add_column :commentaries, :fti_names, "public.tsvector"
    add_column :comments, :fti_names, "public.tsvector"
    add_column :committees, :fti_names, "public.tsvector"
    add_column :people, :fti_names, "public.tsvector"
    add_column :subjects, :fti_names, "public.tsvector"
    add_column :upcoming_bills, :fti_names, "public.tsvector"
  end
end
