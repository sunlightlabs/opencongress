class UserRole < ActiveRecord::Base
  has_many :users
  validates_uniqueness_of :name
  
  def to_hash
    {
      :name => name,
      :can_blog => can_blog,
      :can_administer_users => can_administer_users,
      :can_see_stats => can_see_stats,
      :can_manage_text => can_manage_text,
      :can_moderate_articles => can_moderate_articles,
      :can_edit_blog_tags => can_edit_blog_tags
    }
  end
end
