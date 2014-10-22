# == Schema Information
#
# Table name: user_privacy_option_items
#
#  id                  :integer          not null, primary key
#  user_id             :integer
#  privacy_object_id   :integer
#  privacy_object_type :string(255)
#  method              :string(255)
#  privacy             :integer          default(0)
#  created_at          :datetime
#  updated_at          :datetime
#

class UserPrivacyOptionItem < OpenCongressModel

  PRIVACY_OPTIONS = {
    :private => 0,
    :friends => 1,
    :public => 2
  }

  # fall back to private if all else fails
  DEFAULT_PRIVACY = :private

  DEFAULTS = {
    nil => {
      :public => {
        nil => 2,
      },
      :private => {
        nil => 0,
      }
    },
    'User' => {
      :public => {
        nil => 2,
        'login' => 2,
        'email' => 0,
        'mailing_address' => 0,
        'district' => 2,
        'state' => 2
      },
      :private => {
        nil => 0,
        'login' => 2,
        'email' => 0,
        'mailing_address' => 0,
        'district' => 0,
        'state' => 0
      }
    },
    'BillVote' => {
      :public => {
        nil => 2
      },
      :private => {
        nil => 0
      }
    },
    'Comment' => {
      :public => {
        nil => 2
      },
      :private => {
        nil => 2
      }
    },
    'Bookmark' => {
      :public => {
        nil => 2
      },
      :private => {
        nil => 0
      }
    },
    'Friend' => {
      :public => {
        nil => 2
      },
      :private => {
        nil => 2
      }
    }
  }

  belongs_to :privacy_object, :polymorphic => true
  belongs_to :user


  # Returns whether user argument is allowed to see privacy object
  #
  # @param user [User] user to test if they can see associated privacy object
  # @return [Boolean] true if user can see privacy object, false otherwise
  def can_show_to?(user)
    case self.privacy
      when PRIVACY_OPTIONS[:public]
        return true
      when PRIVACY_OPTIONS[:friend]
        return Friend.are_confirmed_friends?(self.user, user)
      when UserPrivacyOptionItem::PRIVACY_OPTIONS[:private]
        return false
      else
        raise KeyError
    end
  end

  # Retrieves the default privacy setting for arguments
  #
  # @param args [Hash] arguments containing one or more of the following:
  #        item [PrivacyObject] object which includes the privacy_object module
  #        type [String] type of a PrivacyObject for generic privacy setting
  #        method [String] specific method or attribute privacy
  # @return [Integer] default privacy setting
  def self.default_privacy_for(args={item:nil,type:nil,method:nil})

    begin
      args.init_missing_keys(nil, :item, :type, :method)
      type = args[:item].present? ? args[:item].class.name : args[:type]
      return DEFAULTS[type][DEFAULT_PRIVACY][args[:method]]
    rescue TypeError
      return DEFAULT_PRIVACY
    end

  end

  # Returns a temporary default privacy option for input user
  #
  # @param user [User] user to set temporary default privacy for
  # @param args [Hash] arguments containing one or more of the following:
  #        item [PrivacyObject] object which includes the privacy_object module
  #        type [String] type of a PrivacyObject for generic privacy setting
  #        method [String] specific method or attribute privacy
  # @return [UserPrivacyOptionItem] temporary default privacy
  def self.default(user, args={item:nil,type:nil,method:nil})

    begin
      args.init_missing_keys(nil, :item, :type, :method)
      type = args[:item].present? ? args[:item].class.name : args[:type]
      return UserPrivacyOptionItem.new(privacy_object_type: type,
                                       method: args[:method],
                                       user: user,
                                       privacy: default_privacy_for(args))
    rescue
      return UserPrivacyOptionItem.new(user: user,
                                       privacy: PRIVACY_OPTIONS[DEFAULT_PRIVACY])
    end

  end

end