module GoogleRecaptcha

  def self.verified?(response, remoteip, secret = ApiKeys.google_recaptcha_secret_key)
    return true if Rails.env.test?
    begin
      # create URI
      uri = URI.parse('https://www.google.com/recaptcha/api/siteverify')
      params = { :secret => secret, :response => response, :remoteip => remoteip }
      uri.query = URI.encode_www_form( params )

      # construct request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      JSON.parse(http.get2(uri.request_uri).body)['success']
    rescue
      false
    end
  end

end