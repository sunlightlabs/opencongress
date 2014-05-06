require 'openssl'
require 'addressable/uri'

module BlueStateDigital
  # Base call object, shared among api methods
  CallObj = Struct.new(:api_base_uri, :api_secret, :api_id, :api_ver, :ts, :path, :opts)

  ##
  # Accepts a hash of fields (firstname, lastname, city, state, zip, email) and
  # creates an email subscription in BSD Tools. The email and zip fields are
  # mandatory.
  #
  # Returns a hash { :success => bool, :response => HTTParty::Response }
  def self.subscribe_to_email (subscribe_url, fields={})
    # TODO: supporting this signature is a bit of a kludge
    if subscribe_url.is_a? Hash
      fields = subscribe_url
      subscribe_url = nil
    end
    fields = HashWithIndifferentAccess.new fields
    subscribe_url ||= Settings.email_subscription_url

    allowed_params = %W(email firstname lastname city state zip)
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

  def self.email_lookup (email, options={})
    build_call_with(options) do |c|
      c.path = '/page/api/cons/email_lookup'
      c.opts.query_values = { :api_ver => c.api_ver, :api_id => c.api_id, :api_ts => c.ts, :email => email }
    end
  end

  def self.register_by_email (email, options={})
    build_call_with(options) do |c|
      c.path = '/page/api/cons/email_register'
      c.opts.query_values = { :api_ver => c.api_ver, :api_id => c.api_id, :api_ts => c.ts, :email => email, :is_subscribed => 1 }
    end
  end

  ##
  # Accepts an email address to unsubscribe and optional api settings (api_base_uri, api_key, api_id)
  # and attempts to unsubscribe the given email address
  def self.global_unsubscribe_by_email (email, options={})
    build_call_with(options) do |c|
      c.path = '/page/api/cons/email_register'
      c.opts.query_values = { :api_ver => c.api_ver, :api_id => c.api_id, :api_ts => c.ts, :email => email, :is_subscribed => 0 }
    end
  end

  def self.add_to_group_by_email (email, grp_id, options={})
    cons = email_lookup(email, options)['api']['cons_email'] rescue nil
    # Sign user up or re-enable emails if email addr is in a state that doesn't accept emails
    if cons.nil? || cons['is_subscribed'] == '0'
      cons = register_by_email(email)['api']['cons_email']
    end
    build_call_with(options) do |c|
      c.path = '/page/api/cons_group/add_cons_ids_to_group'
      c.opts.query_values = { :api_ver => c.api_ver, :api_id => c.api_id, :api_ts => c.ts, :cons_group_id => grp_id, :cons_ids => cons['cons_id']}
    end
  end

  def self.remove_from_group_by_email (email, grp_id, options={})
    cons = email_lookup(email, options)['api']['cons_email'] rescue nil
    unless cons.nil?
      build_call_with(options) do |c|
        c.path = '/page/api/cons_group/remove_cons_ids_from_group'
        c.opts.query_values = { :api_ver => c.api_ver, :api_id => c.api_id, :api_ts => c.ts, :cons_group_id => grp_id, :cons_ids => cons['cons_id']}
      end
    end
  end

  def self.build_call_with(options, &block)
    call = CallObj.new
    call.api_base_uri = options[:api_base_uri] || Settings.bsd_api_root
    call.api_secret = options[:api_key] || ApiKeys.bsd
    call.api_id = options[:api_id] || Settings.bsd_api_id
    call.api_ver = 2
    call.ts = Time.now.tv_sec
    call.opts = Addressable::URI.new
    yield call
    raw_query = call.opts.query_values.map{|k,v| "#{k}=#{v}"}.join('&')
    signing_string = [call.api_id, call.ts, call.path, raw_query].join("\n")
    signature = OpenSSL::HMAC.hexdigest('sha1', call.api_secret, signing_string)
    root = call.api_base_uri.split('/page/')[0]
    request_url = "#{root}#{call.path}?#{call.opts.query}&api_mac=#{signature}"
    Rails.logger.info("Calling BSD with #{request_url} ...")
    resp = HTTParty.get(request_url)
  end
end
