class ZipInferrenceService

  USPS_BASE_URL = 'https://tools.usps.com/go/ZipLookupResultsAction!input.action'

  # Try to resolve the zip5 and zip4 for a user_profile
  #
  # @param user_profile [UserProfile] instance of UserProfile
  def initialize (user_profile)

    # try to resolve zip first with address using USPS
    if user_profile.street_address.present? and user_profile.city.present? and user_profile.state.present?
      usps_zip_lookup(user_profile)
    end

    # fall back to geocoder if USPS fails
    if user_profile.zipcode.blank? or user_profile.zip_four.blank?
      geocoder_zip_lookup(user_profile)
    end

    user_profile.save!
  end

  # Use geocoder to look up zip5 and zip4
  #
  # @param user_profile [UserProfile] instance of UserProfile
  def geocoder_zip_lookup(user_profile)

    # use geocoder to try and resolve zip4 and zip5
    result = MultiGeocoder.search(user_profile.mailing_address).first
    unless result.nil? or result.postal_code.blank?
      user_profile.zipcode = result.postal_code
      if result.respond_to?(:zip4) and not result.zip4.blank?
        user_profile.zip_four = result.zip4
      end
    end

    user_profile.save
  end

  # Use usps to look up zip5 and zip4
  #
  # @param user_profile [UserProfile] instance of UserProfile
  def usps_zip_lookup(user_profile)

    begin
      # construct get parameters string
      get_params = "resultMode=0&companyName=&address1=#{user_profile.street_address}&address2=&city=#{user_profile.city}&state=#{user_profile.user.state}&urbanCode=&postalCode=&zip="

      # create URI
      uri = URI.parse("#{USPS_BASE_URL}?#{URI.encode(get_params)}")

      # construct request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      data = http.get2(uri.request_uri, 'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.99 Safari/537.36')

      # get response body (html)
      html = data.body

      # regexp for zip5 and zip4
      zip5 = html.match(/\<span class=\"zip\".*>\d{5}\<\/span\>/).to_s.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/,' ').strip
      zip4 = html.match(/\<span class=\"zip4\">\d{4}\<\/span\>/).to_s.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/,' ').strip

      if zip5.match(/\d{5}/) and user_profile.zipcode.blank?
        user_profile.zipcode = zip5
      end

      if zip4.match(/\d{4}/) and user_profile.zip_four.blank?
        user_profile.zip_four = zip4
      end

      user_profile.save
    rescue
      raise unless Rails.env.production?
      Raven.capture_exception(e)
    end
  end

end