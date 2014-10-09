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

  before_create -> { set_link_code }

  belongs_to :notification_aggregate
  belongs_to :notification_outbound

  # Factory for distributing a notification according to
  # the user's settings for that notification type.
  #
  # @param na_id [Integer] id of the NotificationAggregate to distribute
  def self.initiate_distribution(na)

    user = na.user
    na_options = user.notification_option_item(na.activity_key, na.bookmark)

    # TODO: logic from notification settings to create outbounds and associate with notification aggregates

    if na_options.feed == 1
      puts "works"
    end

    if na_options.email == 1
      puts "works"
    end

    if na_options.mobile == 1
      puts "works"
    end

    if na_options.mms_message == 1
      puts "works"
    end

  end

  def set_link_code
    self.code = SecureRandom.hex(32)
  end

end