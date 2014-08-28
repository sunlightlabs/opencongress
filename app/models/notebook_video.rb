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
#  data                  :text
#

class NotebookVideo < NotebookItem
  require 'hpricot'
  require 'open-uri'
  
  # because the table uses STI a regular polymorphic association doesn't work
  has_many :comments, :foreign_key => 'commentable_id', :conditions => "commentable_type='NotebookVideo'"
  
  validates_presence_of :embed, :title
  before_save :set_xy, :make_embed_transparent
  
  def set_xy
    x = /width="(\d*)"/.match(self.embed)
    self.width = x.nil? ? 425 : x[1].to_i
    y = /height="(\d*)"/.match(self.embed)
    self.height = y.nil? ? 344 : y[1].to_i    
  end

  def count_times_bookmarked
    return User.count(:include => :notebook_items, :conditions => ["notebook_items.url = ?", self.url])
  end

  def other_users_bookmarked
    return User.find(:all, :include => :notebook_items, :conditions => ["notebook_items.embed = ? AND users.id <> ?", self.url, self.political_notebook.user.id])
  end
  
  def make_embed_transparent
    return if self.embed.empty?
    
    hp = Hpricot(self.embed)
    hp.at("embed")['wmode'] = "transparent" unless hp.at("embed").nil?
    (hp/"param").last.after('<param name="wmode" value="transparent" />') unless (hp/"param").empty?
    
    self.embed = hp.to_html
  end
end
