# == Schema Information
#
# Table name: geo_ips
#
#  id         :integer          not null, primary key
#  start_ip   :integer
#  end_ip     :integer
#  lat        :string(255)
#  lng        :string(255)
#  state      :string(255)
#  district   :integer
#  created_at :datetime
#  updated_at :datetime
#

require 'spec_helper'

describe GeoIp do
  pending "add some examples to (or delete) #{__FILE__}"
end
