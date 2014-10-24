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