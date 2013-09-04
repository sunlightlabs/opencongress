class MiniMailingList < ActionMailer::Base

  def standard_message(user, bills, people)
     recipients user.email
     from Settings.mini_mailer_from
     subject "OpenCongress Tracking Update"
     body[:bills] = bills
     body[:people] = people
     body[:user] = user
  end

end
