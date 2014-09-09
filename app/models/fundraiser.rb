# == Schema Information
#
# Table name: fundraisers
#
#  id                     :integer          not null, primary key
#  sunlight_id            :integer
#  person_id              :integer
#  host                   :string(255)
#  beneficiaries          :string(255)
#  start_time             :datetime
#  end_time               :datetime
#  venue                  :string(255)
#  entertainment_type     :string(255)
#  venue_address1         :string(255)
#  venue_address2         :string(255)
#  venue_city             :string(255)
#  venue_state            :string(255)
#  venue_zipcode          :string(255)
#  venue_website          :string(255)
#  contributions_info     :string(255)
#  latlong                :string(255)
#  rsvp_info              :string(255)
#  distribution_payer     :string(255)
#  make_checks_payable_to :string(255)
#  checks_payable_address :string(255)
#  committee_id           :string(255)
#

class Fundraiser < OpenCongressModel
  belongs_to :person
end
