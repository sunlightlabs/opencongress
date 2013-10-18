class AddAllIndices < ActiveRecord::Migration
  def self.up
    # CREATE INDEX CONCURRENTLY users_state_index ON users USING btree (state);
    # CREATE INDEX CONCURRENTLY users_state_district_index ON users USING btree (state, district);
    # CREATE INDEX CONCURRENTLY index_users_on_status ON users USING btree (status);
    # CREATE INDEX CONCURRENTLY index_roll_call_votes_on_roll_call_id_and_vote ON roll_call_votes USING btree (roll_call_id, vote);
    # CREATE INDEX CONCURRENTLY index_searches_lower_search_text ON searches USING btree (lower(search_text));
    # CREATE INDEX CONCURRENTLY index_searches_on_created_at ON searches USING btree (created_at);
    # CREATE INDEX CONCURRENTLY index_geo_ips_on_start_ip_and_end_ip ON geo_ips USING btree (start_ip, end_ip);
    # CREATE INDEX CONCURRENTLY index_notebook_items_on_censored ON notebook_items USING btree (censored);
    # CREATE INDEX CONCURRENTLY index_notebook_items_on_spam ON notebook_items USING btree (spam);
    # CREATE INDEX CONCURRENTLY aggregatable_date_poly_idx ON object_aggregates USING btree (date, aggregatable_type, aggregatable_id);

  end

  def self.down
    # remove_index :users, :state
    # remove_index :users, [:state, :district]
    # remove_index :users, :status
    # remove_index :notebook_items, :spam
    # remove_index :notebook_items, :censored
    # remove_index :roll_call_votes, :vote
    # remove_index :object_aggregates, :name => 'aggregatable_date_poly_idx'
    # remove_index :roll_call_votes, [:roll_call_id, :vote]
    # remove_index :searches, :created_at
    # execute "DROP INDEX index_searches_lower_search_text;"
    # remove_index :geo_ips, [:start_ip, :end_ip]
  end
end
