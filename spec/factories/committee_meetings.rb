# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :committee_meeting do
    subject "Pizza party"
    meeting_at Date.today + 1
    where ""
  end
end
