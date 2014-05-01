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

class GeoIp < ActiveRecord::Base
end
