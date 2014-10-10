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

class NotificationOutbound < OpenCongressModel

  #========== CONSTANTS

  OUTBOUND_TYPES = %w(email mms_message mobile)

  #========== FILTERS

  before_create -> { create_receive_code }

  #========== RELATIONS

  has_many :notification_aggregates, :through => :notification_distributors

  #========== METHODS

  #----- INSTANCE

  public

  def is_digest?
    self.is_digest
  end

  def user
    notification_aggregates.last.user
  end

  # TODO: implement delivery cases
  def send_notification

    case outbound_type
      when 'email'
        puts 'Sending email...'
      when 'mms_message'
        puts 'Sending mms...'
      when 'mobile'
        puts 'Sending mobile...'
      else
        logger.error "Outbound type '#{outbound_type}' not found."
    end

  end

  private

  def create_receive_code
    self.receive_code = SecureRandom.hex(32)
  end

end