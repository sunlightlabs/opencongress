class AddSentimentScores < ActiveRecord::Migration

  def self.up

    change_table :comment_scores do |t|
      t.float :polarity
      t.float :subjectivity
    end

  end

  def self.down

    change_table :comment_scores do |t|
      t.remove :polarity
      t.remove :subjectivity
    end

  end

end