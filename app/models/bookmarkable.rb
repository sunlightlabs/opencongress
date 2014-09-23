class Bookmarkable < OpenCongressModel

  #========== MODEL ATTRIBUTES

  self.abstract_class = true
  class_attribute :notification_models

  #========== RELATIONS

  #----- HAS_MANY

  has_many :bookmarks, :dependent => :destroy, :as => :bookmarkable

  #========== CLASS METHODS

  # Custom inherited method
  #
  # @param child [Class] child class inheriting from Bookmarkable
  # @return void
  # @Override
  def self.inherited(child)
    super

    # apply scopes to Bookmarks
    model_str = child.name.downcase
    Bookmark.class_eval do
      scope model_str.pluralize.to_sym, -> { includes(model_str.to_sym).where(:bookmarkable_type => model_str.capitalize) }
      with_options :foreign_key => 'bookmarkable_id' do |b|
        scope = -> { includes :roles } if model_str.to_sym == :person
        b.belongs_to(model_str.to_sym, scope || nil)
      end
    end

    self.after_inherited { child.apply_notification_triggers }
  end

  # This method sets the notification models.
  #
  # @param *relations [Array<Symbol>] symbols for models that trigger notifications
  # @return void
  def self.triggers_notifications(*relations)
    self.notification_models = relations
  end

  # This method uses metaprogramming to add access methods
  # for associated notification models as well as after_create
  # callback to trigger notifications for users tracking the
  # concrete bookmarkable model.
  #
  # @return void
  def self.apply_notification_triggers

    # return if there are no notification_models
    relations = self.notification_models
    return if relations.nil?

    bkm_sym = self.name.underscore.to_sym

    # This code block adds methods dynamically to the bookmarkable
    # concrete class to access the corresponding notifications
    # and notification_objects
    self.class_eval do # new self scope for bookmarkable concrete class

      # Retrieves all notifying_objects for this bookmarkable object
      #
      # @return [Array<NotifyingObject>] aggregated array of all notifying_objects
      def notifying_objects
        ([] << self.notification_models.collect{|r| self.method(r).call }).flatten
      end

      # Retrieves all the notifications associated with this bookmarkable object
      #
      # @return [Array<Notification>] all notifications for this bookmarkable object
      def notifications
        query_params = notifying_objects.collect{|o|
          {notifying_object_id:o.id, notifying_object_type: o.class.name}
        }
        # TODO fix n+1 problem
        return ([] << query_params.collect{|args| Notification.where(args) }).flatten
      end

    end

    relations.each{|r|
      begin

        # get the association object from the bookmarkable model
        reflection = reflect_on_association(r)
        if reflection
          r_class = reflection.options[:class_name] ?
              reflection.options[:class_name].constantize :
              r.to_s.classify.constantize
          r_as = reflection.options[:as] ? reflection.options[:as] : nil
        else
          raise
        end

        # check for plural many-to-many relationship
        if r_as.nil?
          if r_class.reflect_on_association(bkm_sym).nil?
            bkm_sym = bkm_sym.to_s.pluralize.to_sym
            if r_class.reflect_on_association(bkm_sym).nil?
              raise
            end
          end
        end

        # This code block makes the model a notification model
        # and adds callbacks to create notifications for users
        # tracking the parent concrete bookmarkable model.
        r_class.class_eval do # new self scope in associated notifying model

          include NotifyingObject unless include?(NotifyingObject)

          after_create :create_notifications

          self.bookmarkable_models ||= []
          self.bookmarkable_models += [{model:bkm_sym,as:r_as,rel:r}]

          # Creates notifications for users tracking the associated bookmarkable_models
          #
          # @return void
          def create_notifications
            self.bookmarkable_models.each do |obj|
              bookmarkable = self.method(obj[:as]||obj[:model]).call
              bookmarkable = [bookmarkable] unless bookmarkable.respond_to? :each
              bookmarkable.each {|bkm|
                if (bkm.method(obj[:rel]).call).include?(self)
                  bookmarks = Bookmark.where(bookmarkable_type: obj[:model].to_s.classify, bookmarkable_id: bkm.id)
                  bookmarks.each{|bm|
                    Notification.create(notifying_object_id:self.id,
                                        notifying_object_type:self.class.to_s,
                                        user_id:bm.user_id,
                                        seen: 0)
                  }
                end
              }
            end
          end

        end

      rescue
        puts "#{r} isn't a model" # //TODO how to handle this problem?
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