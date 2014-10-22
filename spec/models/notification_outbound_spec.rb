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

require 'spec_helper'

describe NotificationOutbound do

  describe 'create' do

    # insure that NotificationOutbound has a receive code generated for it after creation
    it 'should have a link code' do

      # create an empty NotificationOutbound
      no = NotificationOutbound.create

      expect(no.receive_code).to_not be_nil
    end

  end

end
