# == Schema Information
#
# Table name: comments
#
#  id                :integer          not null, primary key
#  commentable_id    :integer
#  commentable_type  :string(255)
#  comment           :text
#  user_id           :integer
#  name              :string(255)
#  email             :string(255)
#  homepage          :string(255)
#  created_at        :datetime
#  parent_id         :integer
#  title             :string(255)
#  updated_at        :datetime
#  average_rating    :float            default(5.0)
#  censored          :boolean          default(FALSE)
#  ok                :boolean
#  rgt               :integer
#  lft               :integer
#  root_id           :integer
#  fti_names         :public.tsvector
#  flagged           :boolean          default(FALSE)
#  ip_address        :string(255)
#  plus_score_count  :integer          default(0), not null
#  minus_score_count :integer          default(0), not null
#  spam              :boolean
#  defensio_sig      :string(255)
#  spaminess         :float
#  permalink         :string(255)
#  user_agent        :text
#  referrer          :string(255)
#

class BillComment < Comment
  acts_as_tree :order => "id"
end
