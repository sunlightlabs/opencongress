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

  before_create -> { create_link_code }
  after_save -> { notification_outbound.queue_outbound if notification_outbound.respond_to?(:delay_send) }

  #========== SCOPES

  scope :unsent_outbounds, -> (na, d) { where(notification_aggregate_id: na.id)
                                        .includes(:notification_outbound)
                                        .where('notification_outbounds.sent' => 0,
                                               'notification_outbounds.is_digest' => d) }
  scope :with_outbound_type, -> (type) { includes(:notification_outbound)
                                         .where('notification_outbounds.outbound_type' => type) }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :notification_aggregate
  belongs_to :notification_outbound, :dependent => :destroy

  #========== METHODS

  #----- CLASS

  # Factory for distributing a notification according to
  # the user's settings for that notification type.
  #
  # @param na [Integer] id of the NotificationAggregate to distribute
  # @return [Array<NotificationDistributor>, nil] the new NotificationDistributors or nil
  def self.initiate_distribution(na_id)

    begin
      na = NotificationAggregate.find(na_id)
    rescue ActiveRecord::RecordNotFound
      return nil
    end

    # retrieve the user's notification settings for specific activity and bookmarked item
    na_option = na.user.notification_option_item(na.activity_key, na.bookmark)

    # retrieve the distributors for which the associated outbound is unsent and isn't a digest
    u_nd = unsent_outbounds(na, false)

    nd_ary = []

    NotificationOutbound::OUTBOUND_TYPES.each do |type|
      if na_option.send("#{type}?".to_sym) # check whether user wants notification for the outbound type
        u_nd_wtype = u_nd.with_outbound_type(type)
        new_nd = NotificationDistributor.new(notification_aggregate_id: na.id)
        _no =  u_nd_wtype.any? ?
               u_nd_wtype.first.notification_outbound :
               NotificationOutbound.create(outbound_type: type,
                                           is_digest: false,
                                           delay_send: na_option.send("#{type}_frequency".to_sym) )
        new_nd.notification_outbound = _no
        new_nd.save
        nd_ary.append(new_nd)
      end
    end

    return nd_ary

  end

  #----- INSTANCE

  private

  # Generates a random string to use as a secure outward facing identifier
  def create_link_code
    self.link_code = SecureRandom.hex(32)
  end

end