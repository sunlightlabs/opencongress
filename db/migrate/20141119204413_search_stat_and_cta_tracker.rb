class SearchStatAndCtaTracker < ActiveRecord::Migration

  def self.up

    create_table :search_stats do |t|
      t.string :search_text
      t.integer :total_searches
      t.integer :total_avg_per_day
      t.integer :total_unique_users
      t.integer :recent_total_searches
      t.integer :recent_avg_per_day
      t.integer :recent_unique_users
      t.timestamps
    end

    create_table :user_cta_trackers do |t|
      t.belongs_to :user
      t.integer :previous_action_id
      t.text :url_path
      t.string :controller
      t.string :method
      t.text :params
      t.datetime :created_at
    end

  end

  def self.down

    drop_table :search_stats
    drop_table :user_cta_trackers

  end

end