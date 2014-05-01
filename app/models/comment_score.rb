# == Schema Information
#
# Table name: comment_scores
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  comment_id :integer
#  score      :integer
#  created_at :datetime
#  ip_address :string(255)
#

class CommentScore < ActiveRecord::Base
  belongs_to :user
  belongs_to :comment
end
