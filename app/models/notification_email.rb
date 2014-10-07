# == Schema Information
#
# Table name: notification_emails
#
#  id                        :integer          not null, primary key
#  sent                      :integer          default(0)
#  received                  :integer          default(0)
#  code                      :string(255)
#  click_count               :integer          default(0)
#  aggregate_notification_id :integer
#  created_at                :datetime
#  updated_at                :datetime
#

require 'securerandom'

class NotificationEmail < OpenCongressModel

  #========== FILTERS

  before_create -> { set_link_code }
  after_create -> { send_email }

  #========== RELATIONS

  belongs_to :aggregate_notification

  #========== METHODS

  #----- INSTANCE

  public

  def user_email
    aggregate_notification.user.email
  end

  private

  def set_link_code
    self.code = SecureRandom.hex(32)
  end

  def send_email
    UserNotifier.delay.setup_email(self)
  end

end