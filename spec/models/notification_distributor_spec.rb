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

require 'spec_helper'

describe NotificationDistributor do

  describe 'create' do

    # insure that NotificationDistributor has a link code generated for it after creation
    it 'should have a link code' do

      # create an empty NotificationDistributor
      nd = NotificationDistributor.create

      expect(nd.link_code).to_not be_nil

    end

  end


  describe '.initiate_distribution' do

    # This is the case where the class method receives a non-existent
    # NotificationAggregate ID
    it 'should return nil' do

      # pass in non-existent NotificationAggregate ID
      nd = NotificationDistributor.initiate_distribution(0)

      expect(nd).to be_nil

    end

    # This is the case where the user does not wish to receive any notifications
    it 'should return an empty array' do

    end

    #
    it 'should return an array of NotificationDistributor instances' do

    end

    #
    it 'should return an array of NotificationDistributor instances with associated NotificationOutbounds of type email' do

    end

    #
    it 'should return an array of NotificationDistributor instances with associated NotificationOutbounds of type mms_message' do

    end

    #
    it 'should return an array of NotificationDistributor instances with associated NotificationOutbounds of type feed' do

    end

    #
    it 'should return an array of NotificationDistributor instances with associated NotificationOutbounds of type mobile' do

    end

  end

end
