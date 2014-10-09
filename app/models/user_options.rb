# == Schema Information
#
# Table name: user_options
#
#  id                  :integer          not null, primary key
#  user_id             :integer
#  comment_threshold   :integer          default(5)
#  opencongress_mail   :boolean          default(TRUE)
#  partner_mail        :boolean          default(FALSE)
#  sms_notifications   :boolean          default(FALSE)
#  email_notifications :boolean          default(TRUE)
#  feed_key            :string(255)
#

require_dependency 'email_listable'

class UserOptions < OpenCongressModel

  #========== INCLUDES

  include EmailListable

  #========== CONSTANTS

  HUMANIZED_ATTRIBUTES = {
    :opencongress_mail => "OpenCongress mailing preference",
    :partner_mail => "Partner mailing preference"
  }

  #========== FILTERS

  update_email_subscription_when_changed :user, [:opencongress_mail, :partner_mail]
  before_save :ensure_feed_key

  #========== RELATIONS

  #----- BELONGS TO

  belongs_to :user

  #========== METHODS

  #----- INSTANCE

  public

  def reset_feed_key
    update_attribute(:feed_key, generate_feed_key)
  end

  protected

  def ensure_feed_key
    self.feed_key = generate_feed_key unless feed_key.present?
  end

  def generate_feed_key
    SecureRandom.uuid
  end

end