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

  attr_accessor :outbound_timeframe

  #========== METHODS

  #----- INSTANCE

  public

  def is_digest?
    self.is_digest
  end

  def user
    notification_aggregates.last.user
  end

  def queue_outbound
    send_notification
    self.update_attributes!({sent: 1})
  end

  private

  # TODO: implement the delivery cases
  def send_notification
    self.send("send_#{outbound_type}".to_sym) rescue logger.error "Outbound type '#{outbound_type}' not found."
  end

  def send_email
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