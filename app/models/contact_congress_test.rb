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
#  submitted_form      :text
#

class ContactCongressTest < ActiveRecord::Base
  scope :latest, -> { select("distinct on (bioguideid) *").order("bioguideid, created_at DESC") }
  scope :passed, -> { where("status like ?", "SENT") }
  scope :failed, -> { where("status like ? or status like ?", "%ERROR%", "%SENT_AS_FAX%") }
  scope :unknown, -> { where("status like ? or status like ?", "%WARNING%", "%START%") }
  scope :captcha_required, -> { where("status like ?", "%CAPTCHA_REQUIRED%") }

  class << self
    def recently_passed
      latest.to_a.select{|t| t.status =~ /\ASENT\Z/ }
    end

    def recently_failed
      latest.to_a.select{|t| t.status =~ /ERROR|SENT_AS_FAX/ }
    end

    def recently_unknown
      latest.to_a.select{|t| t.status =~ /WARNING/ }
    end

    def recently_captcha_required
      latest.to_a.select{|t| t.status =~ /CAPTCHA_REQUIRED/ }
    end
  end
end
