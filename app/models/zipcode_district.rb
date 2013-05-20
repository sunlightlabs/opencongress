class ZipcodeDistrict < ActiveRecord::Base

  default_scope order("state ASC, district ASC")

  def self.zip_lookup(zip5, zip4 = nil)
    if zip4.blank?
      self.select("DISTINCT state, district").where(["zip5 = ?", zip5]).all
    else
      self.select("DISTINCT state, district").where(["zip5 = ? AND (zip4 = ? OR zip4 = 'xxxx')", zip5, zip4]).all
    end
  end

  def self.from_address(address)
    zip5, zip4 = Geocoder.search(address)[0].data['postalCode'].split('-')
    return ZipcodeDistrict.zip_lookup(zip5, zip4) unless zip5.blank?
    return nil
  end

end