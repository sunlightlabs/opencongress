FactoryGirl.define do
  factory :user_profile do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.first_name }
    street_address "123 Fake Street"
    city "Mount Vernon"
    mobile_phone 7032983014
    zipcode 36560
  end
end