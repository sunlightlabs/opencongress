# == Schema Information
#
# Table name: upcoming_bills
#
#  id         :integer          not null, primary key
#  title      :text
#  summary    :text
#  created_at :datetime
#  updated_at :datetime
#  fti_names  :public.tsvector
#

class UpcomingBill < OpenCongressModel
  
  has_many :news, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='t'").order('commentaries.date DESC') },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :blogs, -> { where("commentaries.is_ok = 't' AND commentaries.is_news='f'").order('commentaries.date DESC') },
           :as => :commentariable, :class_name => 'Commentary'
  has_many :comments,
           :as => :commentable
  has_many :friend_emails, -> { order('created_at') },
           :as => :emailable
  
  def display_object_name
    'upcoming bill'
  end 
  
  def to_param
    "#{id}-#{title.gsub(/[^a-z0-9]+/i, '-')}"
  end
end
