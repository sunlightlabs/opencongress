FactoryGirl.define do
  factory :congress_session do
    chamber 'senate'
    date DateTime.now
    is_in_session true
  end
end