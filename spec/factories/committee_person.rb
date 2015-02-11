FactoryGirl.define do
  factory :committee_person do 
    role "Chair"
    session { Settings.default_congress }
  end
end
