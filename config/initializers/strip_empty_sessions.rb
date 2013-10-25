require 'strip_empty_sessions'
OpenCongress::Application.configure do
  facebook_app_id = ApiKeys.fetch(:facebook_app_id, 'xxx')
  config.middleware.insert_before("ActionDispatch::Cookies",
                                  "StripEmptySessions",
                                  { :session_cookie => "_opencongress_session",
                                    :loggedin_cookie => "ocloggedin",
                                    :flashmsg_cookie => "ocflashmessage",

                                    # These are the keys in the session data that are considered disposable
                                    # if they are the only keys in the session.
                                    :bogus_keys => ["session_id", "_csrf_token"],

                                    # These are the cookies that will be forcibly expired after a user who
                                    # is logged out views a page that does not require customization.
                                    :extra_cookies => ["sessionid", "csrfokten", "fbsr_#{facebook_app_id}"],
                                    :extra_cookie_pattern => /fbm_.+/
                                  })
end

