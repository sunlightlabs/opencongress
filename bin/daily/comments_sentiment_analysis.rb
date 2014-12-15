#!/usr/bin/env ruby

Comment.includes(:comment_scores).all.each do |comment|

  comment_scores = comment.comment_scores

  if comment_scores.empty? or (comment_scores.any? and  comment_scores.first.polarity.nil?)

    # get sentiment scores
    scores = `python bin/sentiment_analysis.py "#{comment.comment.gsub('"','\"')}"`
    scores = scores.gsub(/\)|\(/,'').strip.split(',').map{|i| i.to_f}

    if comment_scores.empty?
      CommentScore.create(user_id:comment.user_id,
                          comment_id:comment.id,
                          score:0,
                          polarity:scores[0],
                          subjectivity: scores[1],
                          ip_address:comment.ip_address)
    else
      comment_scores.first.update_attributes(polarity:scores[0],subjectivity:scores[1])
    end
  end
end