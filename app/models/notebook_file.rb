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

class NotebookFile < NotebookItem
  has_attached_file :file, :styles => { :medium => "300x300>", :thumb => "100x100>" },
                    :path => "#{Settings.notebook_files_path}/:id/:style/:filename",
                    :url => "#{Settings.notebook_files_url}/:id/:style/:filename"

  # because the table uses STI a regular polymorphic association doesn't work
  has_many :comments, -> { where("commentable_type='NotebookFile'") },
           :foreign_key => 'commentable_id',
           :dependent => :destroy

  # has_attachment :content_type => ['application/pdf', :image,'application/msword', 'text/plain'],
  #   :storage => :file_system,
  #   :max_size => 1024.kilobytes,
  #   :resize_to => '600x>',
  #   :thumbnails => {
  #     :small => '48x48>',
  #     :medium => '200x>'
  #   }
  #
  # validates_as_attachment

  validates_presence_of :title

  def can_render_thumbnail?
    self.image? rescue false
  end

  def filesytem_path
    Rails.root.join("public", public_filename)
  end

  def item_div(size, item_id)
    height = NotebookFile.find(:first,
                      :conditions => ["thumbnail = ? AND parent_id = ?", size, item_id])
    return height.height
  end

end
