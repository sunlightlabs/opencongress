# == Schema Information
#
# Table name: notification_outbounds
#
#  id            :integer          not null, primary key
#  sent          :integer          default(0)
#  received      :integer          default(0)
#  receive_code  :string(255)
#  outbound_type :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  is_digest     :boolean
#

require 'securerandom'

class NotificationOutbound < OpenCongressModel

  #========== CONSTANTS

  OUTBOUND_TYPES = %w(email mms_message mobile feed)
  DEFAULT_OUTBOUND_TIMEFRAME = 3600 # seconds

  #========== FILTERS

  before_create -> { create_receive_code }

  #========== RELATIONS

  has_many :notification_aggregates, :through => :notification_distributors
  has_many :notification_distributors

  #========== ACCESSORS

  attr_accessor :delay_send

  #========== METHODS

  #----- INSTANCE

  public

  def is_digest?
    self.is_digest
  end

  def user
    notification_aggregates.last.user
  end

  def queue_outbound(delay=false)
    if delay
      self.delay_for(delay_send.present? ? delay_send : DEFAULT_OUTBOUND_TIMEFRAME, :retry => 3).send_notification
    else
      self.send_notification
    end
  end

  # TODO: implement the delivery cases
  def send_notification
    begin
      if Settings.send_notifications?
        self.send("send_#{outbound_type}".to_sym)
        self.update_attributes!({sent: 1})
      end
    rescue NoMethodError
      logger.error "Outbound type '#{outbound_type}' not found for send_notification."
    rescue Settingslogic::MissingSetting
      logger.error 'config/application_settings.yml is missing send_notifications?'
    rescue
      logger.error 'Unknown error in send_notification'
    end
  end

  private

  def send_email
    puts "sending notification email..."
    NotificationMailer.setup_email(self).deliver
  end

  def send_mms_message
    puts "send mms message with code #{receive_code} and #{notification_distributors.count} distributors"
  end

  def send_mobile
    puts "send mobile with code #{receive_code} and #{notification_distributors.count} distributors"
  end

  def send_feed
    puts "send feed with code #{receive_code} and #{notification_distributors.count} distributors"
  end

  def create_receive_code
    self.receive_code = SecureRandom.hex(32)
  end

end
