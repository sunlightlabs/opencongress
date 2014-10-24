# == Schema Information
#
# Table name: user_ip_addresses
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  addr       :integer
#  created_at :datetime
#  updated_at :datetime
#

require 'ipaddr'

class UserIpAddress < OpenCongressModel

  #========== RELATIONS

  #----- BELONGS TO

  belongs_to :user

  #========== METHODS

  #----- CLASS

  def self.find_by_ip(address)
     ip = UserIpAddress.int_form(address)
     self.find_by_addr(ip)
  end

  def self.find_all_by_ip(address)
     ip = UserIpAddress.int_form(address)
     self.where(addr:ip).order('created_at DESC')
  end

  def self.int_form(address)
    IPAddr.new(address).to_i
  end

  #----- INSTANCE

  public

  def to_s
    IPAddr.new(self.addr, Socket::AF_INET).to_s
  end

end