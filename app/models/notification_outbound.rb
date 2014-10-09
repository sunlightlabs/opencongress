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
#

class NotificationOutbound < OpenCongressModel

  before_create -> { create_receive_code }
  after_create -> { send_notification }

  has_many :notification_aggregates, :through => :notification_distributors

  private

  def create_receive_code
    self.code = SecureRandom.hex(32)
  end

  # TODO: implement these cases
  def send_notification

    case outbound_type
      when 'email'
        puts 'Sending email...'
      when 'mms'
        puts 'Sending mms...'
      when 'mobile'
        puts 'Sending mobile...'
      else
        logger.error "Outbound type '#{outbound_type}' not found."
    end

  end

end
