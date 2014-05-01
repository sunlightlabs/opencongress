# == Schema Information
#
# Table name: panel_referrers
#
#  id           :integer          not null, primary key
#  referrer_url :text             not null
#  panel_type   :string(255)
#  views        :integer          default(0)
#  updated_at   :datetime
#

class PanelReferrer < ActiveRecord::Base
end
