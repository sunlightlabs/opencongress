# == Schema Information
#
# Table name: notifications
#
#  id                        :integer          not null, primary key
#  created_at                :datetime
#  updated_at                :datetime
#  activities_id             :integer
#  aggregate_notification_id :integer
#

require 'rails_helper'

RSpec.describe Notification, :type => :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
