# (session cookie in request)   (logged in after request)   (flash message in session data)
# 
# y y y leave set-cookies alone
# y y n leave set-cookies alone
# y n n drop set-cookies
# y n y add ocflashmessage set-cookie
# n y y leave set-cookies alone
# n n y leave set-cookies alone but add ocflashmessage to set-cookie
# n n n drop set-cookies
# n y n leave set-cookies alone
class StripEmptySessions
  ENV_SESSION_KEY = "rack.session".freeze
  HTTP_SET_COOKIE = "Set-Cookie".freeze

  def initialize(app, options = {})
    @app = app
    @options = options
    @bogus_keys = options.fetch(:bogus, []).uniq
  end

  def call(env)
    logger = @logger || env['rack.errors']

    status, headers, body = @app.call(env)

    session_data = env[ENV_SESSION_KEY]
    logger.write "StripEmptySessions: session_data.keys = #{session_data.to_s}"
    sc = headers[HTTP_SET_COOKIE]
    if (session_data.keys - @bogus_keys).empty?
      if sc.is_a? Array
        logger.write "KILLING COOKIE FROM ARRAY #{@options[:key]}"
        sc.reject! {|c| c.match(/^\n?#{@options[:key]}=/)}
        @options.fetch(:extra_keys, []).each do |k|
          logger.write "KILLING COOKIE FROM ARRAY #{k}"
          sc.reject! {|c| c.match(/^\n?#{k}=/)}
        end
      elsif sc.is_a? String
        logger.write "KILLING COOKIE #{@options[:key]}"
        headers[HTTP_SET_COOKIE].gsub!( /(^|\n)#{@options[:key]}=.*?(\n|$)/, "" )
        @options.fetch(:extra_keys, []).each do |k|
          logger.write "KILLING COOKIE #{k}"
          headers[HTTP_SET_COOKIE].gsub!( /(^|\n)#{k}=.*?(\n|$)/, "" )
        end
      end
    end

    [status, headers, body]
  end

end
