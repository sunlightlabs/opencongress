# == Schema Information
#
# Table name: user_privacy_options
#
#  id                 :integer          not null, primary key
#  name               :integer          default(1)
#  email              :integer          default(0)
#  zipcode            :integer          default(1)
#  location           :integer          default(2)
#  profile            :integer          default(2)
#  actions            :integer          default(2)
#  bookmarks          :integer          default(2)
#  friends            :integer          default(2)
#  user_id            :integer
#  created_at         :datetime
#  updated_at         :datetime
#  political_notebook :integer          default(2)
#  watchdog           :integer          default(2)
#  groups             :integer          default(2)
#

class UserPrivacyOptions < OpenCongressModel

  belongs_to :user

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

  # sets all options to private
  def privatize!
    ACCESSIBLE_ATTRS.map{|att| self.send("#{att}=".to_sym, 0)}
    save
  end

end