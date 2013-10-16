class AddTermAndTimestampIndexesToSearches < ActiveRecord::Migration
  def self.up
    # add_index :searches, :created_at
    # execute "CREATE INDEX index_searches_lower_search_text ON searches USING btree (lower(search_text));"
  end

  def self.down
    # remove_index :searches, :created_at
    # execute "DROP INDEX index_searches_lower_search_text;"
  end
end
