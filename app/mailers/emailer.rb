class Emailer < ActionMailer::Base

  def send_sponsors(to, from, subject, text, sent_at = Time.now)
    @subject    = subject
    @body       = {:content => text}
    @recipients = to
    @from       = "#{from}"
    @sent_on    = sent_at
    @headers    = {}
  end

  def send_person(to, from, subject, text, sent_at = Time.now)
    @subject    = subject
    @body       = {:content => text}
    @recipients = to
    @from       = "#{from}"
    @sent_on    = sent_at
    @headers    = {}
  end

  def error_snapshot(exception, trace, session, params, env, sent_on = Time.now)
    content_type "text/html"

    @recipients         = 'oc-errors@lists.ppolitics.org'
    @from               = 'Open Congress Logger <noreply@opencongress.org>'
    @subject            = "Exception in #{env['REQUEST_URI']}"
    @sent_on            = sent_on
    @body["exception"]  = exception
    @body["trace"]      = trace
    @body["session"]    = session
    @body["params"]     = params
    @body["env"]        = env
  end

  def rake_error(exception, message)
    @subject    = "OpenCongress Rake Task Error"
    @recipients = "oc-rake-errors@lists.ppolitics.org"
    @from       = 'Open Congress Rake Tasks <noreply@opencongress.org>'
    @body['exception'] = exception
    @body['message'] = message
    @body['time'] = Time.now
  end

  def friend(to, from, subject, url, item_desc, message)
    @subject      = subject
    @recipients   = to
    @from         = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @sender_email = from
    @headers      = { :reply_to => @sender_email }
    @item_url     = url
    @item_desc    = item_desc
    @message      = message
  end

  def invite(to, from, url, message)
    @recipients   = to
    @from         = "\"OpenCongress Friends\" <friends@opencongress.org>"
    @sender_email = from
    @headers      = { :reply_to => @sender_email }
    @url          = url
    @message      = message
    @subject      = "#{CGI::escapeHTML(from)} invites you to join OpenCongress"
    @sent_on      = Time.now
  end

  def feedback(params)
    @recipients = Settings.contact_emails
    @from = "\"OpenCongress\" <noreply@opencongress.org>"
    @subject = "[OpenCongress #{Rails.env}] Message from #{@name} (#{@from})"
    @name = params[:name]
    @sender_email = params[:email]
    @message = params[:message]
    @sent_on = params[:sent_on] || Time.now
  end
end
