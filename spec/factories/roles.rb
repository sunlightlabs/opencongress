FactoryGirl.define do
  factory :role do
    role_type "rep"
    startdate NthCongress.start_datetime(Settings.default_congress)
    enddate NthCongress.end_datetime(Settings.default_congress)
  end
end