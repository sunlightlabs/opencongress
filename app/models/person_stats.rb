# == Schema Information
#
# Table name: person_stats
#
#  person_id                               :integer          not null, primary key
#  entered_top_viewed                      :datetime
#  votes_most_often_with_id                :integer
#  votes_least_often_with_id               :integer
#  opposing_party_votes_most_often_with_id :integer
#  same_party_votes_least_often_with_id    :integer
#  entered_top_news                        :datetime
#  entered_top_blog                        :datetime
#  sponsored_bills                         :integer
#  cosponsored_bills                       :integer
#  sponsored_bills_passed                  :integer
#  cosponsored_bills_passed                :integer
#  sponsored_bills_rank                    :integer
#  cosponsored_bills_rank                  :integer
#  sponsored_bills_passed_rank             :integer
#  cosponsored_bills_passed_rank           :integer
#  party_votes_percentage                  :float
#  party_votes_percentage_rank             :integer
#  abstains_percentage                     :float
#  abstains                                :integer
#  abstains_percentage_rank                :integer
#  unabstains                              :integer
#  unabstains_rank                         :integer
#  party_votes_count                       :integer
#

class PersonStats < OpenCongressModel

  self.primary_key = 'person_id'
  
  belongs_to :person
  
  belongs_to :votes_most_often_with, :class_name => 'Person', :foreign_key => 'votes_most_often_with_id'
  belongs_to :votes_least_often_with, :class_name => 'Person', :foreign_key => 'votes_least_often_with_id'
  belongs_to :opposing_party_votes_most_often_with, :class_name => 'Person', :foreign_key => 'opposing_party_votes_most_often_with_id'
  belongs_to :same_party_votes_least_often_with, :class_name => 'Person', :foreign_key => 'same_party_votes_least_often_with_id'
  
  def full_name
    "#{firstname} #{lastname}"
  end

  def title_full_name
		"#{title} " + full_name
	end
	
end
