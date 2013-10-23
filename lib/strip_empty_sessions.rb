class StripEmptySessions
  ENV_SESSION_KEY = "rack.session".freeze
  HTTP_SET_COOKIE = "Set-Cookie".freeze
  BOGUS_KEYS = %w(session_id _csrf_token)

  def initialize(app, options = {})
    puts "==================================="
    puts "StripEmptySessions.initialize"
    puts "==================================="
    @app = app
    @options = options
  end

  def call(env)
    puts "==================================="
    puts "StripEmptySessions.call"

    status, headers, body = @app.call(env)

    session_data = env[ENV_SESSION_KEY]
    puts session_data.to_s
    puts "==================================="
    sc = headers[HTTP_SET_COOKIE]
    if env["cookie.logout"]
      value = Hash.new
      value[:value] = "x"
      value[:expires] = Time.now - 1.year
      cookie = build_cookie(@options[:key], value.merge(@options))

      if sc.nil?
        headers[HTTP_SET_COOKIE] = cookie if env["cookie.logout"]
      elsif sc.is_a? Array
        sc << cookie if env["cookie.logout"]
      elsif sc.is_a? String
        headers[HTTP_SET_COOKIE] << "\n#{cookie}" if env["cookie.logout"]
      end
    elsif (session_data.keys - BOGUS_KEYS).empty?
      if sc.is_a? Array
        sc.reject! {|c| c.match(/^\n?#{@options[:key]}=/)}
      elsif sc.is_a? String
        headers[HTTP_SET_COOKIE].gsub!( /(^|\n)#{@options[:key]}=.*?(\n|$)/, "" )
      end
    end

    [status, headers, body]
  end

  private

  # Copied from the cookie session middleware.
  def build_cookie(key, value)
    case value
    when Hash
      domain  = "; domain="  + value[:domain] if value[:domain]
      path    = "; path="    + value[:path]   if value[:path]
      # According to RFC 2109, we need dashes here.
      # N.B.: cgi.rb uses spaces...
      expires = "; expires=" + value[:expires].clone.gmtime.
        strftime("%a, %d-%b-%Y %H:%M:%S GMT") if value[:expires]
      secure = "; secure" if value[:secure]
      httponly = "; HttpOnly" if value[:httponly]
      value = value[:value]
    end
    value = [value] unless Array === value
    Rack::Utils.escape(key) + "=" +
      value.map { |v| Rack::Utils.escape(v) }.join("&amp;") +
      "#{domain}#{path}#{expires}#{secure}#{httponly}"
  end
end
