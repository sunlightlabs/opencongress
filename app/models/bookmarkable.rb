class Bookmarkable < OpenCongressModel

  self.abstract_class = true

  has_many :bookmarks, :dependent => :destroy

  def find_bookmarking_users
    User.where(id:Bookmark.where(bookmarkable_id:id).collect{|b|b.user_id})
  end

end