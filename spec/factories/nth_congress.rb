FactoryGirl.define do
  factory :nth_congress do
    number 114
    start_date { NthCongress.start_datetime(number) }
    end_date { NthCongress.end_datetime(number) }
  end
end