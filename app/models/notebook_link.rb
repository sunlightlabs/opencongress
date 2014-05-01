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

#class NotebookLink < ActiveRecord::Base
class NotebookLink < NotebookItem
  require 'hpricot'
  require 'open-uri'
    
  validates_presence_of :url, :title

  # because the table uses STI a regular polymorphic association doesn't work
  has_many :comments, :foreign_key => 'commentable_id', :conditions => "commentable_type='NotebookLink'", :dependent => :destroy
  
  attr_accessor :bill_type, :bill_number
  
  def is_internal?
    !notebookable_type.blank? && !notebookable_id.blank?
  end
  
  def init_from_notebookable(notebookable)
    case notebookable.class.to_s
    when 'Bill'
      self.title = "OpenCongress: #{notebookable.title_short}" if self.title.blank?
      self.url = "internal"
    when 'Subject'
      self.title = "OpenCongress: #{notebookable.term}" if self.title.blank?
      self.url = "internal"      
    when 'Person'
      self.title = "OpenCongress: #{notebookable.name}" if self.title.blank?
      self.url = "internal"      
    when 'ContactCongressLetter'
      self.title = notebookable.formageddon_threads.first.formageddon_letters.first.subject if self.title.blank?
      self.url = "internal"
      self.description = "#{notebookable.formageddon_threads.first.formageddon_letters.first.message[0..250]}..."      
    when 'Commentary'
      self.title = notebookable.title if self.title.blank?
      self.url = notebookable.url
    end
  end
  
  def count_times_bookmarked
    if self.notebookable
      #return NotebookItem.count(:conditions => ["notebookable_type = ? AND notebookable_id = ?", self.notebookable_type, self.notebookable_id])
      return User.count(:include => :notebook_items, :conditions => ["notebook_items.notebookable_type = ? AND notebook_items.notebookable_id = ?", self.notebookable_type, self.notebookable_id])

    else
      return User.count(:include => :notebook_items, :conditions => ["notebook_items.url = ?", self.url])
      #return NotebookItem.count(:conditions => ["url = ?", self.url])
    end
  end

  def other_users_bookmarked
    if self.notebookable
      return User.find(:all, :include => :notebook_items, :conditions => ["notebook_items.notebookable_type = ? AND notebook_items.notebookable_id = ? AND users.id <> ?", self.notebookable_type, self.notebookable_id, self.political_notebook.user.id])
    else
      return User.find(:all, :include => :notebook_items, :conditions => ["notebook_items.url = ? AND users.id <> ?", self.url, self.political_notebook.user.id])
    end
  end

end
