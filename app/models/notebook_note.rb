# == Schema Information
#
# Table name: notebook_items
#
#  id                    :integer          not null, primary key
#  political_notebook_id :integer
#  type                  :string(255)
#  url                   :string(255)
#  title                 :string(255)
#  date                  :string(255)
#  source                :string(255)
#  description           :text
#  is_internal           :boolean
#  embed                 :text
#  created_at            :datetime
#  updated_at            :datetime
#  parent_id             :integer
#  size                  :integer
#  width                 :integer
#  height                :integer
#  filename              :string(255)
#  content_type          :string(255)
#  thumbnail             :string(255)
#  notebookable_type     :string(255)
#  notebookable_id       :integer
#  hot_bill_category_id  :integer
#  file_file_name        :string(255)
#  file_content_type     :string(255)
#  file_file_size        :integer
#  file_updated_at       :datetime
#  group_user_id         :integer
#  user_agent            :string(255)
#  ip_address            :string(255)
#  spam                  :boolean
#  censored              :boolean
#

class NotebookNote < NotebookItem
  
  
  validates_presence_of :description
  
  # because the table uses STI a regular polymorphic association doesn't work
  has_many :comments, :foreign_key => 'commentable_id', :conditions => "commentable_type='NotebookNote'"
end
