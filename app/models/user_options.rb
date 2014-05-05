# == Schema Information
#
# Table name: user_options
#
#  id                  :integer          not null, primary key
#  user_id             :integer
#  comment_threshold   :integer          default(5)
#  opencongress_mail   :boolean          default(TRUE)
#  partner_mail        :boolean          default(FALSE)
#  sms_notifications   :boolean          default(FALSE)
#  email_notifications :boolean          default(TRUE)
#

require_dependency 'email_listable'

class UserOptions < ActiveRecord::Base
  include EmailListable

  HUMANIZED_ATTRIBUTES = {
    :opencongress_mail => "OpenCongress mailing preference",
    :partner_mail => "Partner mailing preference"
  }

  belongs_to :user
  update_email_subscription_when_changed user, [:opencongress_mail, :partner_mail]

end
