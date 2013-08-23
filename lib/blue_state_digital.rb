require 'openssl'
require 'addressable/uri'

module BlueStateDigital
  ##
  # Accepts a hash of fields (firstname, lastname, city, state, zip, email) and
  # creates an email subscription in BSD Tools. The email and zip fields are
  # mandatory.
  #
  # Returns a hash { :success => bool, :response => HTTParty::Response }
  def self.subscribe_to_email (subscribe_url, fields)
    allowed_params = ["email", "firstname", "lastname", "city", "state", "zip"]
    headers = {"Content-Type" => "application/x-www-form-urlencoded"}
    body = fields.select{|k,v| allowed_params.include? k.to_s }
    begin
      resp = HTTParty.post(subscribe_url, :body => body, :headers => headers, :no_follow => true)
    rescue HTTParty::RedirectionTooDeep => e
      resp = e.response
    end

    success = (resp.code == "302" && resp.body =~ /thanks/)
    { :success => success, :response => resp }
  end

  ##
  # Accepts an email address to unsubscribe and optional api settings (api_base_uri, api_key, api_id)
  # and attempts to unsubscribe the given email address
  def self.unsubscribe_by_email (email, options={})
    api_base_uri = options[:api_base_uri] || Settings.bsd_api_root
    api_secret = options[:api_key] || ApiKeys.bsd
    api_id = options[:api_id] || Settings.bsd_api_id
    api_ver = 2
    ts = Time.now.tv_sec
    root = api_base_uri.split('/page/')[0]
    path = '/page/api/cons/email_unsubscribe'
    opts = Addressable::URI.new
    opts.query_values = { :api_ver => api_ver, :api_id => api_id, :api_ts => ts, :email => email, :reason => "User Requested" }
    raw_query = opts.query_values.map{|k,v| "#{k}=#{v}"}.join('&')
    signing_string = [api_id, ts, path, raw_query].join("\n")
    puts signing_string
    signature = OpenSSL::HMAC.hexdigest('sha1', api_secret, signing_string)
    puts signature
    resp = HTTParty.get("#{root}#{path}?#{opts.query}&api_mac=#{signature}")
  end
end
