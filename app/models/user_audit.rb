# == Schema Information
#
# Table name: user_audits
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  email      :string(255)
#  email_was  :string(255)
#  full_name  :string(255)
#  district   :string(255)
#  zipcode    :string(255)
#  state      :string(255)
#  created_at :datetime
#  processed  :boolean          default(FALSE), not null
#  mailing    :boolean          default(FALSE), not null
#

class UserAudit < ActiveRecord::Base

end
