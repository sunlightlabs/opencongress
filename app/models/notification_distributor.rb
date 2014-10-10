# == Schema Information
#
# Table name: notification_distributors
#
#  id                        :integer          not null, primary key
#  notification_aggregate_id :integer
#  notification_outbound_id  :integer
#  link_code                 :string(255)
#  view_count                :integer          default(0)
#  stop_request              :integer          default(0)
#  created_at                :datetime
#  updated_at                :datetime
#

require 'securerandom'

class NotificationDistributor < OpenCongressModel

  #========== FILTERS

  before_create -> { set_link_code }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :notification_aggregate
  belongs_to :notification_outbound

  #========== METHODS

  #----- CLASS

  # Factory for distributing a notification according to
  # the user's settings for that notification type.
  #
  # @param na [Integer] id of the NotificationAggregate to distribute
  def self.initiate_distribution(na_id)

    na = NotificationAggregate.find(na_id)

    if na.present?
      na_options = na.user.notification_option_item(na.activity_key, na.bookmark)

      nd = NotificationDistributor.where(notification_aggregate_id: na.id)
                                  .joins(:notification_outbound).where('notification_outbounds.sent' => 0,
                                                                       'notification_outbounds.is_digest' => false)

      NotificationOutbound::OUTBOUND_TYPES.each do |type|
        if na_options.send(type.to_sym) == 1
          no = nd.joins(:notification_outbound).where('notification_outbounds.outbound_type' => type)
          new_nd = NotificationDistributor.new(notification_aggregate_id: na.id)
          _no = no.first.present? ? no.first.notification_outbound : NotificationOutbound.create(outbound_type: type.to_s, is_digest: false)
          new_nd.notification_outbound = _no
          new_nd.save
          # TODO : check if _no should be sent now either because last email was sent past the threshold value or user wants notifications immediately (small delay to allow mass notifications)
        end
      end
    else
      nil
    end

  end

  #----- INSTANCE

  private

  def set_link_code
    self.link_code = SecureRandom.hex(32)
  end

end