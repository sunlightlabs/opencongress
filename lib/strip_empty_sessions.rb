require 'pp'

class StripEmptySessions
  def initialize(app, options = {})
    @app = app
    @options = options
    @session_cookie_name = options[:session_cookie]
    @logged_in_cookie_name = options[:loggedin_cookie]
    @flash_message_cookie_name = options[:flashmsg_cookie]
    @bogus_keys = options.fetch(:bogus_keys, []).uniq
    @cookies_to_reset = options.fetch(:extra_cookies, []) + [@session_cookie_name, @logged_in_cookie_name, @flash_message_cookie_name]
    @regexp_cookies_to_reset = options[:extra_cookie_pattern]
  end

  def call(env)
    req = Rack::Request.new(env)
    logger = @logger || env['rack.errors']

    logger.write("=====================================\n")
    logger.write(req.path)

    request_cookies = req.cookies.clone

    @session_cookie_in_request = request_cookies.keys.include?(@session_cookie_name)
    @logged_in_before_request = request_cookies.keys.include?(@logged_in_cookie_name) && @session_cookie_in_request

    status, headers, body = @app.call(env)

    set_cookie_lines = headers.fetch('Set-Cookie', '').lines.map(&:strip).to_a

    @logged_out_by_response = set_cookie_lines.select{ |c| c.starts_with?("#{@logged_in_cookie_name}=;") }.any?
    @logged_in_by_request = set_cookie_lines.select{ |c| c.starts_with?("#{@logged_in_cookie_name}=true") }.any?
    @logged_in_after_response = (@logged_in_before_request || @logged_in_by_request) && !@logged_out_by_response

    session_data = req.session.clone
    @flash_msg_in_session = session_data.keys.include?("flash")

    @session_is_sparse = (session_data.keys - @bogus_keys).empty?

    logger.write("@session_cookie_in_request = #{@session_cookie_in_request}\n")
    logger.write("@logged_in_after_response = #{@logged_in_after_response}\n")
    logger.write("@flash_msg_in_session = #{@flash_msg_in_session}\n")
    logger.write("@session_is_sparse = #{@session_is_sparse}\n")


    if @logged_in_after_response
      logger.write("User is logged in")
      # We do nothing here. Logged-in users should never be cached.
      # The session cookie should prevent caching.
    elsif @flash_msg_in_session
      logger.write("Session has flash message only")
      # Reponses that contain flash messages are customized for the user
      # despite being logged out. We add an ocflashmessage cookie to
      # signal to varnish that the response should not be cached.

      # remove existing flash message cookie (should not happen, just defensive) to avoid duplicating.
      set_cookie_lines.select!{ |c| not c.starts_with? "{@flash_message_cookie_name}=" }
      set_cookie_lines << build_cookie(@flash_message_cookie_name, :value => 'true')
    elsif not @session_is_sparse
      # The user is logged out and there is no flash message. However,
      # there is data in the session beyond the session id and csrf token.
      # They are probably being shuffled through a login step prior to
      # commenting or creating a letter. Leave the headers alone.
      logger.write("Session has: #{pp session_data}")
    else
      logger.write("Nothing special going on here...")
      # The user is logged out, the page is not customized for them, and
      # we don't have any session data needed to customize future pages.
      # Drop all existing Set-Cookie headers and add new ones to expire
      # the cookies seen in the request so that future requests are
      # cachable by varnish.

      set_cookie_lines = []
      request_cookies.select {|cookie_name, cookie|
        @cookies_to_reset.include?(cookie_name) || (@regexp_cookies_to_reset.present? && cookie_name =~ @regexp_cookies_to_reset)
      }
      .each do |cookie_name, cookie|
        # Facebook login cookies have a value like 'domain=.example.com', which
        # we can use to determine what domain we should expire the cookie on.
        # if the cookie name matches and we have a valid domain, then merge in
        # a domain property to build_cookie
        domain = cookie.scan(/^base_domain=([^;]+)/).first.first rescue nil
        if domain
          logger.write("#{cookie_name} has domain #{domain}")
        else
          logger.write("#{cookie_name} has no domain.")
        end
        cookie_opts = {:value => nil, :expires => Time.new(1970, 1, 1)}
        cookie_opts.merge!({:domain => domain}) if cookie_name =~ /^fbm_/ && domain.present?
        set_cookie_lines << build_cookie(cookie_name, cookie_opts)
      end
      logger.write("Deleting: #{pp set_cookie_lines}")
    end

    if set_cookie_lines.empty?
      headers.delete 'Set-Cookie'
    else
      headers['Set-Cookie'] = set_cookie_lines.join("\n")
    end

    [status, headers, body]
  end

  private

  # Copied from the cookie session middleware.
  def build_cookie(key, value)
    # No known use for path-restricted cookies
    value.merge!(:path => '/')
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
