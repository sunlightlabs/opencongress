class PrivacyOption < ActiveRecord::Base
  belongs_to :user
  after_save :save_associated_user

  ACCESSIBLE_ATTRS = [:my_full_name, :my_email, :my_last_login_date, :my_zip_code,
                      :my_instant_messenger_names, :my_website, :my_location, :about_me,
                      :my_actions, :my_tracked_items, :my_friends, :my_congressional_district,
                      :my_political_notebook, :watchdog]

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

  private
  def save_associated_user
    #self.user.solr_save
  end
end
