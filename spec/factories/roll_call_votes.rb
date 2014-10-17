# == Schema Information
#
# Table name: roll_call_votes
#
#  id           :integer          not null, primary key
#  vote         :string(255)
#  roll_call_id :integer
#  person_id    :integer
#

FactoryGirl.define do
  factory :roll_call_vote do
    trait :default do
      vote "+"
      roll_call
      person
    end
    
    #This doesn't create all associated roll_call_votes, just sets the magical 'republican_position' column    
    trait :republican_voting_with_party do
      vote "+"
      association :roll_call, :republican_position => true
      association :person, :party => 'Republican'
    end
    trait :republican_voting_against_party do
      vote "-"
      association :roll_call, :republican_position => true
      association :person, :party => 'Republican'
    end
  end
end
