# == Schema Information
#
# Table name: user_privacy_options
#
#  id                 :integer          not null, primary key
#  name               :integer          default(0)
#  email              :integer          default(0)
#  zipcode            :integer          default(0)
#  location           :integer          default(0)
#  profile            :integer          default(0)
#  actions            :integer          default(0)
#  bookmarks          :integer          default(0)
#  friends            :integer          default(0)
#  user_id            :integer
#  created_at         :datetime
#  updated_at         :datetime
#  political_notebook :integer          default(2)
#  watchdog           :integer          default(2)
#

class UserPrivacyOptions < ActiveRecord::Base
  belongs_to :user

  ACCESSIBLE_ATTRS = %w(name email zipcode location profile actions friends
                        political_notebook watchdog groups).map(&:to_sym)

  PRIVACY_OPTIONS = {
    :private => 0,
    :friends => 1,
    :public => 2
  }

  class << self
    def get_option_keys
      ACCESSIBLE_ATTRS
    end

    def get_option_values
      PRIVACY_OPTIONS
    end
  end

  attr_accessible *ACCESSIBLE_ATTRS

  # sets all options to private
  def privatize!
    ACCESSIBLE_ATTRS.map{|att| self.send("#{att}=".to_sym, 0)}
    save
  end
end
