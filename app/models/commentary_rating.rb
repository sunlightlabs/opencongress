# == Schema Information
#
# Table name: commentary_ratings
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  commentary_id :integer
#  rating        :integer
#  created_at    :datetime
#  updated_at    :datetime
#

class CommentaryRating < OpenCongressModel

  belongs_to :commentary
  belongs_to :user

end
