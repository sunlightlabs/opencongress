# == Schema Information
#
# Table name: contact_congress_tests
#
#  id                  :integer          not null, primary key
#  bioguideid          :string(255)
#  status              :text
#  after_browser_state :text
#  values              :text
#  created_at          :datetime
#  updated_at          :datetime
#

class ContactCongressTest < ActiveRecord::Base
  scope :latest, -> { select("distinct on (bioguideid) *").order("bioguideid, created_at DESC") }
  scope :passed, -> { where("status like ?", "SENT") }
  scope :failed, -> { where("status like ? or status like ?", "%ERROR%", "%SENT_AS_FAX%") }
  scope :unknown, -> { where("status like ? or status like ?", "%WARNING%", "%START%") }
  scope :captcha_required, -> { where("status like ?", "%CAPTCHA_REQUIRED%") }
end
