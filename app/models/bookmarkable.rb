class Bookmarkable < OpenCongressModel

  #========== ATTRIBUTES

  self.abstract_class = true

  #========== RELATIONS

  #----- HAS_MANY

  has_many :bookmarks, :dependent => :destroy, :as => :bookmarkable

  #========== METHODS

  #----- INSTANCE

  public

  # Finds all users currently bookmarking this bookmarkable object
  #
  # @return [Relation<User>] users currently bookmarking this bookmarkable object
  def find_bookmarking_users
    User.where(id:Bookmark.where(bookmarkable_id:id).collect{|b|b.user_id})
  end

end