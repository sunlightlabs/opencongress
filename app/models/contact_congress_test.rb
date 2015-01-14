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

  #========== CONSTANTS

  STATUSES = {
    passed: ['SENT'],
    failed: ['ERROR','SENT_AS_FAX'],
    unknown: ['WARNING'],
    captcha_required: ['CAPTCHA_REQUIRED']
  }

  #========== SCOPES

  scope :latest, -> { select('distinct on (bioguideid) *').order('bioguideid, created_at DESC') }

  STATUSES.each do |k,v|
    scope k, -> { where(v.collect{|i| "status like '%#{i}%'"}.join(' OR ')) }
    scope ("recently_#{k}".to_sym), -> { latest.send(k) }
  end

end
