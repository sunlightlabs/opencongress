module SentimentObject
  extend ActiveSupport::Concern

  included do
    has_many :sentiment_scores, :as => :sentimental
  end



end