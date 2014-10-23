# This module is to be included in models which should have associated
# privacy settings. The model MUST belong to a user (foreign key to user_id)
# as otherwise user privacy options can't be associated with instances of that model
# The essential method of this module is "can_show_to?" which returns true
# or false depending on whether the viewer argument can view the instance
# according to the owning user's privacy settings. The second argument (method)
# is optional and if included checks for the granular method/attribute privacy

module PrivacyObject
  extend ActiveSupport::Concern

  included do
    has_many :privacy_options, :as => :privacy_object, :class_name => 'UserPrivacyOptionItem'
    after_create :set_initial_privacy
  end

  #========== METHODS

  #----- CLASS

  def self.abstract_class?
    true
  end

  module ClassMethods

    # Updates all user's privacy options for included type
    #
    # @param user [User] user to set privacy for
    # @param privacy [Symbol] privacy level
    def update_all_privacies(user, privacy)
      user.user_privacy_option_items
          .where(privacy_object_type:self.name)
          .update_all(privacy:UserPrivacyOptionItem.default_privacy_for(type:self.name,privacy))
    end

  end

  #----- INSTANCE

  public

  # Determines if the input user can see the current object
  #
  # @param viewer [User] viewing user to determine if they can see this
  # @param method [String] granular attribute or method control
  # @return [Boolean] true if input user can see object, false otherwise
  def can_show_to?(viewer, method=nil)
    privacy_options.where(method:method).first.can_show_to?(viewer)
  end

  # Sets privacy for this PrivacyObject and method
  #
  # @param privacy [Symbol] :public, :friend, :private
  # @param method [String]
  def set_privacy(privacy, method=nil)
    privacy_options.create(privacy:privacy, method:method, user_id: user_id)
  end

  # Update privacy for this PrivacyObject and method
  #
  # @param privacy [Symbol] :public, :friend, :private
  # @param method [String] method to update privacy of
  def update_privacy(privacy, method=nil)
    privacy_options.where(method:method).first.update(privacy:UserPrivacyOptionItem::PRIVACY_OPTIONS[privacy])
  end

  # Collects all the viewable methods to the input user
  #
  # @param viewer [User] viewing user
  # @return [Array<String>] array of viewable methods for Privacyobject by viewer
  def viewable_methods_for(viewer)
    viewable = [UserPrivacyOptionItem::PRIVACY_OPTIONS[:public]]
    viewable.push(UserPrivacyOptionItem::PRIVACY_OPTIONS[:friend]) if Friend.are_confirmed_friends?(self.user, viewer)
    privacy_options.where(privacy:viewable).collect {|i| i.method }
  end

  private

  # Sets the initial privacy for the newly created PrivacyObject
  # by using the defaults established when a User is first created
  def set_initial_privacy

    if self.class.name == 'User' # set all defaults for new user
      user.set_all_default_privacies(:private)
    else # apply default options to new PrivacyObject
      upoi = user.user_privacy_option_items.where(privacy_object_type: self.class.name,
                                                  privacy_object_id: nil)
      upoi.each do |item| # set default privacy for specific instance
        new_upoi = item.dup
        new_upoi.privacy_object_id = self.id
        new_upoi.save
      end
    end

  end

end