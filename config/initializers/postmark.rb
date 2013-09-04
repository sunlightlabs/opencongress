ActionMailer::Base.postmark_settings = {
  :api_key => ApiKeys.postmark
}

ActionMailer::Base.default :from => Settings.email_from_address