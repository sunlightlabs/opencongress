class Bookmarkable < OpenCongressModel

  #========== MODEL ATTRIBUTES

  self.abstract_class = true
  class_attribute :notification_models

  #========== RELATIONS

  #----- HAS_MANY

  has_many :bookmarks, :dependent => :destroy, :as => :bookmarkable

  #========== CLASS METHODS

  # This method is called in concrete subclasses passing in the
  # models that should trigger notifications.
  #
  # @param *relations [Array<Symbol>] symbols for models that trigger notifications
  # @return void
  def self.triggers_notifications(*relations)
    self.notification_models = relations
    bkm_sym = self.name.underscore.to_sym

    self.class_eval do
      def notifications
        puts self.notification_models
      end

      def notification_objects
        [] << self.notification_models.collect{|r|
          self.method(r).call
        }
      end
    end

    relations.each{|r|
      begin
        r_class = r.to_s.classify.constantize
        if r_class.include?(NotifyingObject)
          r_class.class_eval do # new self scope

            after_create :create_notifications

            self.bookmarkable_models = (self.bookmarkable_models || [bkm_sym]) + [bkm_sym]

            def create_notifications
              bkm_syms = self.bookmarkable_models
              bkm_syms.each do |sym|
                bookmarkable = self.method(sym).call
                bookmarks = Bookmark.where(bookmarkable_type: sym.to_s.classify, bookmarkable_id: bookmarkable.id)
                bookmarks.each{|bm|
                  Notification.create(notifying_object_id:self.id,
                                      notifying_object_type:self.class.to_s,
                                      user_id:bm.user_id,
                                      seen: 0)
                }
              end
            end

          end
        else
          puts "#{r_class.to_s} doesn't include NotifyingObject!"  # //TODO how to handle this problem?
        end
      rescue NameError => e
        puts "#{r_class.to_s} isn't a model" # //TODO how to handle this problem?
      end
    }
  end

  #========== INSTANCE METHODS

  # Finds all users currently bookmarking this bookmarkable object
  #
  # @return [Relation<User>] users currently bookmarking this bookmarkable object
  def find_bookmarking_users
    User.where(id:Bookmark.where(bookmarkable_id:id).collect{|b|b.user_id})
  end

end