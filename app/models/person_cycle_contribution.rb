# == Schema Information
#
# Table name: people_cycle_contributions
#
#  id                     :integer          not null, primary key
#  person_id              :integer
#  total_raised           :integer
#  top_contributor_id     :integer
#  top_contributor_amount :integer
#  cycle                  :string(255)
#  updated_at             :datetime
#

class PersonCycleContribution < ActiveRecord::Base
  self.table_name = :people_cycle_contributions
  
  belongs_to :person
  belongs_to :top_contributor, :class_name => 'Contributor', :foreign_key => 'top_contributor_id' #Ha!
end
