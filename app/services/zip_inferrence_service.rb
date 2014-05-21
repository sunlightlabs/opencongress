class ZipInferrenceService

  def initialize (user_profile)
    if user_profile.zipcode.blank? || user_profile.zip_four.blank?
      result = MultiGeocoder.search(user_profile.mailing_address).first
      unless result.nil? || result.zipcode.blank?
        user_profile.zipcode = result.zipcode
        unless result.zip4.blank?
          user_profile.zip_four = result.zip4
        end
      end
      user_profile.save!
    end
  end

end

