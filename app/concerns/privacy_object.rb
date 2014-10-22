module PrivacyObject

  extend ActiveSupport::Concern

  included do
    has_many :privacy_options, :as => :privacy_object, :class_name => 'UserPrivacyOptionItem'
  end

  def self.abstract_class?
    true
  end

  # Determines if the input user can see the current object
  #
  # @param user [User] user to determine if they can see
  # @param method [String] granular attribute or method control
  # @return [Boolean] true if input user can see object, false otherwise
  def can_show_to?(user, method=nil)
    privacy_options.where(method:method).first.can_show_to?(user)
  end

  def viewable_methods_for(user, method=nil)
    viewable = [UserPrivacyOptionItem::PRIVACY_OPTIONS[:public]]
    viewable.push(UserPrivacyOptionItem::PRIVACY_OPTIONS[:friend]) if Friend.are_confirmed_friends?(self.user, user)
    upoi = method.nil? ? privacy_options.where(privacy:viewable) : privacy_options.where(privacy:viewable, method: method)
    upoi.collect {|i| i.method }
  end

end