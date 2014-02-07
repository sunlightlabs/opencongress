class RemoveTsvectorupdateTrigger < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      DROP TRIGGER IF EXISTS upcoming_bill_tsvectorupdate ON upcoming_bills;
      DROP TRIGGER IF EXISTS subject_tsvectorupdate ON subjects;
      DROP TRIGGER IF EXISTS people_tsvectorupdate ON people;
      DROP TRIGGER IF EXISTS committee_tsvectorupdate ON committees;
      DROP TRIGGER IF EXISTS comments_tsvectorupdate ON comments;
      DROP TRIGGER IF EXISTS commentary_tsvectorupdate ON commentaries;
      DROP TRIGGER IF EXISTS bill_tsvectorupdate ON bill_fulltext;
      DROP TRIGGER IF EXISTS bill_titles_tsvectorupdate ON bill_titles;
      DROP TRIGGER IF EXISTS article_tsvectorupdate ON articles;
    SQL
  end
end
